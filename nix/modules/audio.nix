{ config, lib, pkgs, ... }:
{
  options.services.karaoke.audio.enable = lib.mkEnableOption "PipeWire + SingStar mic config";

  config = lib.mkIf config.services.karaoke.audio.enable {
    # TODO: PipeWire on. SingStar composite USB device split: ch1, ch2 → independent sources.
  };
}
