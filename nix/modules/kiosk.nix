{ config, lib, pkgs, ... }:
{
  options.services.karaoke.kiosk.enable = lib.mkEnableOption "USDX kiosk session";

  config = lib.mkIf config.services.karaoke.kiosk.enable {
    # TODO: autologin to `karaoke` user, no DM, compositor launches USDX fullscreen.
    # TODO: USDX crash → relaunch loop (never expose desktop).
  };
}
