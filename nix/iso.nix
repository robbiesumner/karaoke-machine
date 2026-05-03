{ config, lib, pkgs, ... }:
{
  # Installer ISO. Wipes target disk, installs the appliance, reboots into the
  # first-boot wizard. Modules are stubs today — ISO build proves the flake wires
  # up; real installer logic lands as the modules fill in.

  image.baseName = lib.mkForce "karaoke";

  services.karaoke.kiosk.enable = false;
  services.karaoke.audio.enable = false;
  services.karaoke.samba.enable = false;
  services.karaoke.firstboot.enable = false;
  services.karaoke.networking.enable = false;
}
