{ self, config, lib, pkgs, ... }:
let
  cfg = config.services.karaoke.installer;

  # Project source staged into the installer ISO so `nixos-install --flake`
  # works fully offline. Both the ISO and the karaoke target evaluate from the
  # same flake.lock, so all inputs are already in the ISO's nix store.
  flakeSrc = lib.sources.cleanSourceWith {
    name = "karaoke-src";
    src = self;
    filter = path: _type:
      let base = baseNameOf (toString path); in
      base != ".git"
      && base != "result"
      && base != ".idea"
      && !(lib.hasSuffix ".qcow2" base);
  };

  installer = pkgs.writeShellApplication {
    name = "karaoke-installer";
    runtimeInputs = with pkgs; [
      newt
      coreutils
      util-linux
      gptfdisk
      dosfstools
      e2fsprogs
      nixos-install-tools
      systemd
      parted
    ];
    text = ''
      TITLE="Karaoke Kiosk — installer"
      FLAKE_SRC="/etc/karaoke-src"

      die() {
        whiptail --title "$TITLE" --msgbox "Install failed:\n\n$1\n\nDropping to a root shell on tty2 — press Enter to retry from the start." 14 70
      }

      pick_disk() {
        # Identify the live medium so we never offer it as a target. squashfs
        # backing store lives at /nix/.ro-store; resolve its source device's
        # parent disk and exclude it from the menu.
        live_part=$(findmnt -no SOURCE /nix/.ro-store 2>/dev/null || true)
        live_disk=""
        if [ -n "$live_part" ]; then
          live_disk=$(lsblk -no PKNAME "$live_part" 2>/dev/null || true)
        fi

        mapfile -t disks < <(lsblk -dn -o NAME,SIZE,MODEL,TYPE \
          | awk '$NF=="disk" {$NF=""; print}')

        menu_args=()
        for line in "''${disks[@]}"; do
          name=$(echo "$line" | awk '{print $1}')
          rest=$(echo "$line" | cut -d' ' -f2- | sed 's/[[:space:]]*$//')
          if [ -n "$live_disk" ] && [ "$name" = "$live_disk" ]; then
            continue
          fi
          menu_args+=("$name" "$rest")
        done

        if [ ''${#menu_args[@]} -eq 0 ]; then
          die "No installable disks found."
          return 1
        fi

        DISK=$(whiptail --title "$TITLE" \
          --menu "Choose target disk to ERASE and install onto.\n\n(The USB you booted from is hidden.)" \
          18 70 8 "''${menu_args[@]}" 3>&1 1>&2 2>&3) || return 1
      }

      confirm_erase() {
        size=$(lsblk -dn -o SIZE "/dev/$DISK")
        model=$(lsblk -dn -o MODEL "/dev/$DISK" || true)
        whiptail --title "$TITLE" --yesno \
          "About to ERASE /dev/$DISK ($size $model).\n\nALL DATA ON THIS DISK WILL BE DESTROYED.\n\nContinue?" \
          12 70 || return 1

        typed=$(whiptail --title "$TITLE" --inputbox \
          "Type ERASE in capital letters to confirm." 10 60 "" 3>&1 1>&2 2>&3) || return 1
        [ "$typed" = "ERASE" ] || {
          whiptail --title "$TITLE" --msgbox "Confirmation did not match. Aborted." 8 50
          return 1
        }
      }

      partition() {
        local dev="/dev/$DISK"
        # gptfdisk --zap-all clears both GPT and MBR; partprobe forces the
        # kernel to re-read the table so /dev/disk/by-label appears before mkfs.
        sgdisk --zap-all "$dev"
        sgdisk \
          -n1:0:+512M -t1:EF00 -c1:ESP \
          -n2:0:0     -t2:8300 -c2:nixos \
          "$dev"
        partprobe "$dev"
        udevadm settle

        # /dev/sda1 vs /dev/nvme0n1p1 — gptfdisk follows kernel naming.
        if [[ "$DISK" =~ [0-9]$ ]]; then
          esp="''${dev}p1"; root="''${dev}p2"
        else
          esp="''${dev}1"; root="''${dev}2"
        fi

        mkfs.fat -F32 -n BOOT "$esp"
        mkfs.ext4 -F -L nixos "$root"
      }

      do_install() {
        mount /dev/disk/by-label/nixos /mnt
        mkdir -p /mnt/boot
        mount /dev/disk/by-label/BOOT /mnt/boot

        # --no-root-passwd: appliance has no interactive root login.
        # --no-channel-copy: ISO has no channels; flake locks all inputs.
        nixos-install \
          --root /mnt \
          --flake "$FLAKE_SRC#karaoke" \
          --no-root-passwd \
          --no-channel-copy
      }

      run_once() {
        pick_disk || return 1
        confirm_erase || return 1

        clear
        echo "Partitioning /dev/$DISK..."
        partition || { die "Partitioning failed."; return 1; }

        echo "Installing — this can take several minutes."
        do_install || { die "nixos-install failed."; return 1; }

        whiptail --title "$TITLE" --msgbox \
          "Install complete.\n\nRemove the installer USB and press Enter to reboot." \
          10 60
        systemctl reboot
      }

      while :; do
        if run_once; then
          break
        fi
      done
    '';
  };
in
{
  options.services.karaoke.installer.enable =
    lib.mkEnableOption "Karaoke ISO installer wizard";

  config = lib.mkIf cfg.enable {
    environment.etc."karaoke-src".source = flakeSrc;

    # Ship the karaoke target's toplevel in the ISO closure so nixos-install
    # has nothing left to fetch. Without this nixos-install would need to
    # build the target from inputs at install time — slow and fragile.
    system.extraDependencies = [
      self.nixosConfigurations.karaoke.config.system.build.toplevel
    ];

    # Owns tty1 the whole time the installer is up. Mirrors the firstboot
    # wizard pattern (see nix/modules/firstboot.nix) — same fd-routing, same
    # getty conflict.
    systemd.services.karaoke-installer = {
      description = "Karaoke ISO installer";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-user-sessions.service" ];
      conflicts = [ "getty@tty1.service" ];

      serviceConfig = {
        Type = "idle";
        ExecStart = lib.getExe installer;
        StandardInput = "tty";
        StandardOutput = "tty";
        StandardError = "tty";
        TTYPath = "/dev/tty1";
        TTYReset = true;
        TTYVHangup = true;
        User = "root";
      };
    };
  };
}
