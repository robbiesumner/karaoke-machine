{ config, lib, pkgs, ... }:
{
  options.services.karaoke.networking.enable = lib.mkEnableOption "NetworkManager + avahi (mDNS)";

  config = lib.mkIf config.services.karaoke.networking.enable {
    # TODO: NetworkManager + avahi (so `\\karaoke.local\songs` resolves on the LAN).
  };
}
