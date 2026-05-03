{ config, lib, pkgs, ... }:
{
  options.services.karaoke.firstboot.enable = lib.mkEnableOption "First-boot WiFi/hostname wizard";

  config = lib.mkIf config.services.karaoke.firstboot.enable {
    # TODO: systemd unit on tty1, gated by sentinel, whiptail TUI for WiFi + hostname.
  };
}
