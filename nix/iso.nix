{ config, lib, pkgs, ... }:
{
  # Installer ISO. Wipes target disk, installs the appliance, reboots into the
  # first-boot wizard. Appliance modules stay disabled here — they belong to
  # the installed system, not the live medium.

  image.baseName = lib.mkForce "karaoke-installer";

  services.karaoke.kiosk.enable = false;
  services.karaoke.audio.enable = false;
  services.karaoke.samba.enable = false;
  services.karaoke.firstboot.enable = false;
  services.karaoke.networking.enable = false;
  services.karaoke.installer.enable = true;

  # installation-cd-minimal.nix autologins a `nixos` user on every TTY. Free
  # tty1 so the installer wizard's `conflicts = getty@tty1.service` is enough
  # without a confusing autologin flash before the wizard takes over.
  services.getty.autologinUser = lib.mkForce null;
}
