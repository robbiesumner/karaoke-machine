{ config, lib, pkgs, ... }:
let
  cfg = config.services.karaoke.firstboot;

  sentinel = "/var/lib/karaoke/.firstboot-done";
  nmConnDir = "/etc/NetworkManager/system-connections";

  # whiptail TUI for WiFi setup. Loops on cancel — kiosk is gated on the
  # sentinel this script writes, so an aborted wizard would leave tty1 dark.
  # Hostname is fixed to "karaoke" (set declaratively in nix/system.nix);
  # no per-device customization in v1.
  wizard = pkgs.writeShellApplication {
    name = "karaoke-firstboot-wizard";
    runtimeInputs = with pkgs; [ newt coreutils systemd ];
    text = ''
      TITLE="Karaoke Kiosk — first-boot setup"

      ssid=""
      psk=""

      while :; do
        if ! ssid=$(whiptail --title "$TITLE" \
            --inputbox "WiFi network name (SSID).\n\nLeave blank if using a wired connection." \
            12 64 "$ssid" 3>&1 1>&2 2>&3); then
          continue
        fi

        if [ -n "$ssid" ]; then
          if ! psk=$(whiptail --title "$TITLE" \
              --passwordbox "WiFi password for \"$ssid\"." \
              10 64 3>&1 1>&2 2>&3); then
            continue
          fi
          if [ -z "$psk" ]; then
            whiptail --title "$TITLE" \
              --msgbox "Password cannot be empty." 8 50
            continue
          fi
        fi

        summary="WiFi: ''${ssid:-(none — wired)}"
        if whiptail --title "$TITLE" --yesno "$summary\n\nApply and reboot?" 11 64; then
          break
        fi
      done

      install -d -m 0755 /var/lib/karaoke
      install -d -m 0700 ${nmConnDir}

      if [ -n "$ssid" ]; then
        # NetworkManager keyfile. UUID omitted — NM generates one on first
        # load. Must be mode 0600 or NM refuses the file.
        conn="${nmConnDir}/$ssid.nmconnection"
        umask 077
        {
          printf '[connection]\nid=%s\ntype=wifi\nautoconnect=true\n\n' "$ssid"
          printf '[wifi]\nmode=infrastructure\nssid=%s\n\n' "$ssid"
          printf '[wifi-security]\nkey-mgmt=wpa-psk\npsk=%s\n\n' "$psk"
          printf '[ipv4]\nmethod=auto\n\n'
          printf '[ipv6]\nmethod=auto\n'
        } > "$conn"
        chmod 600 "$conn"
      fi

      touch ${sentinel}

      whiptail --title "$TITLE" --msgbox "Setup complete. Rebooting." 8 40
      systemctl reboot
    '';
  };
in
{
  options.services.karaoke.firstboot.enable =
    lib.mkEnableOption "First-boot WiFi wizard";

  config = lib.mkIf cfg.enable {
    # Sentinel parent. Samba's tmpfiles rule covers only the songs subdir.
    systemd.tmpfiles.rules = [
      "d /var/lib/karaoke 0755 root root -"
    ];

    # Wizard owns tty1 until the sentinel appears. cage-tty1 is gated below,
    # so on first boot only this unit drives the console.
    systemd.services.karaoke-firstboot = {
      description = "Karaoke first-boot WiFi wizard";
      wantedBy = [ "multi-user.target" ];
      before = [ "cage-tty1.service" ];
      after = [ "systemd-user-sessions.service" ];
      conflicts = [ "getty@tty1.service" ];

      unitConfig = {
        ConditionPathExists = "!${sentinel}";
      };

      serviceConfig = {
        Type = "idle";
        ExecStart = lib.getExe wizard;
        # All three to tty: whiptail draws on stdout, returns on stderr, and
        # the wizard swaps fds (`3>&1 1>&2 2>&3`) inside `$(…)` to capture
        # the value while keeping the TUI on screen. If stderr is journald,
        # the swap routes the TUI to the journal pipe and tty1 stays blank.
        StandardInput = "tty";
        StandardOutput = "tty";
        StandardError = "tty";
        TTYPath = "/dev/tty1";
        TTYReset = true;
        TTYVHangup = true;
        # Wizard writes root-owned NM keyfiles + sentinel.
        User = "root";
      };
    };

    # Kiosk only starts once the wizard has finished. Without this gate, cage
    # would race the wizard for tty1 on first boot. cage's own module already
    # sets ConditionPathExists=/dev/tty1; pass a list so both conditions AND
    # (systemd treats repeated ConditionPathExists= as logical AND).
    systemd.services.cage-tty1 = {
      unitConfig.ConditionPathExists = lib.mkForce [ "/dev/tty1" sentinel ];
      after = [ "karaoke-firstboot.service" ];
    };
  };
}
