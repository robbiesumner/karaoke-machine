{ config, lib, pkgs, ... }:
{
  options.services.karaoke.samba.enable = lib.mkEnableOption "Songs Samba share";

  config = lib.mkIf config.services.karaoke.samba.enable {
    # TODO: share `songs` → /var/lib/karaoke/songs/, read-write, no auth, SMB2+.
  };
}
