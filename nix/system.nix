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
  };
}
