{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  services.karaoke.kiosk.enable = true;
  services.karaoke.audio.enable = true;
  services.karaoke.samba.enable = true;
  services.karaoke.firstboot.enable = true;
  services.karaoke.networking.enable = true;

  networking.hostName = lib.mkDefault "karaoke";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Silent boot. Hide the kernel/systemd log wall between firmware handover
  # and the cage compositor coming up — appliance UX, not a workstation.
  # If something breaks early, switch to a TTY (Ctrl+Alt+F2) and re-enable
  # by editing the boot entry's cmdline.
  boot.consoleLogLevel = 3;
  boot.kernelParams = [
    "quiet"
    "loglevel=3"
    "rd.systemd.show_status=false"
    "systemd.show_status=false"
    "udev.log_level=3"
    "vt.global_cursor_default=0"
  ];

  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  system.stateVersion = "25.11";

  # VM-only debug surface — SSH on host port 2222 so smoke tests can inspect
  # the kiosk session journal. Does not affect the appliance ISO.
  virtualisation.vmVariant = {
    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
      settings.PermitEmptyPasswords = "yes";
    };
    users.users.root.hashedPassword = "";
    security.pam.services.sshd.allowNullPassword = true;
    virtualisation.forwardPorts = [
      { from = "host"; host.port = 2222; guest.port = 22; }
    ];

    # qemu has no GPU acceleration; let wlroots fall back to llvmpipe so cage
    # can actually render. Real hardware has a real GPU and won't need this.
    services.cage.environment = {
      WLR_RENDERER_ALLOW_SOFTWARE = "1";
    };

    # No SingStar dongle in the VM — synthesise the upstream stereo source so
    # the channel-split loopbacks still produce two named mono sources.
    services.karaoke.audio.stubSource = true;

    # Keep VM boot loud so smoke tests can read kernel/systemd output on the
    # serial console. Real hardware uses the silent params from the parent.
    boot.kernelParams = lib.mkForce [ ];
    boot.consoleLogLevel = lib.mkForce 4;
  };
}
