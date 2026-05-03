{ config, lib, pkgs, ... }:
let
  cfg = config.services.karaoke.samba;
in
{
  options.services.karaoke.samba = {
    enable = lib.mkEnableOption "Songs Samba share";

    songsDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/karaoke/songs";
      description = "Filesystem path exposed as the //karaoke/songs share.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Songs land here. Owned by the kiosk user so USDX (running as karaoke)
    # reads drops written through Samba without permission games. tmpfiles
    # guarantees the dir exists before smbd starts on first boot.
    systemd.tmpfiles.rules = [
      "d ${cfg.songsDir} 0775 karaoke users -"
    ];

    services.samba = {
      enable = true;
      openFirewall = true;

      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "Karaoke";
          "server role" = "standalone server";
          # LAN-only appliance, no auth UX. Any failed auth (incl. anonymous
          # from Finder/Explorer) gets mapped to the guest account so dropping
          # files "just works".
          "security" = "user";
          "map to guest" = "Bad User";
          "guest account" = "karaoke";
          # SMB2+ only. SMB1 is off by default in modern Samba; keep it off.
          "server min protocol" = "SMB2";
          # Don't advertise printers we don't have.
          "load printers" = "no";
          "printing" = "bsd";
          "printcap name" = "/dev/null";
          "disable spoolss" = "yes";
        };

        songs = {
          "path" = cfg.songsDir;
          "browseable" = "yes";
          "read only" = "no";
          "guest ok" = "yes";
          "guest only" = "yes";
          # Whoever connects, files end up owned by the kiosk user so USDX
          # can read them. "users" is karaoke's primary group.
          "force user" = "karaoke";
          "force group" = "users";
          "create mask" = "0664";
          "directory mask" = "0775";
        };
      };
    };
  };
}
