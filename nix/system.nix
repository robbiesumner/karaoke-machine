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
}
