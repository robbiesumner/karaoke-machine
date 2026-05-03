{ config, lib, pkgs, ... }:
let
  cfg = config.services.karaoke.audio;

  # Two loopback modules tap channels off the SingStar source ("singstar_raw")
  # and expose each as an independent mono source ("singstar_mic1" / "_mic2").
  # USDX selects them per player from its audio dialog; choice persists in
  # ~/.config/ultrastardx/config.ini after first pick.
  singstarSplit = {
    "context.modules" = [
      {
        name = "libpipewire-module-loopback";
        args = {
          "node.description" = "SingStar Mic 1";
          "capture.props" = {
            "node.name" = "singstar_mic1_capture";
            "target.object" = "singstar_raw";
            "stream.dont-remix" = true;
            "audio.position" = [ "FL" ];
          };
          "playback.props" = {
            "node.name" = "singstar_mic1";
            "media.class" = "Audio/Source/Virtual";
            "audio.position" = [ "MONO" ];
          };
        };
      }
      {
        name = "libpipewire-module-loopback";
        args = {
          "node.description" = "SingStar Mic 2";
          "capture.props" = {
            "node.name" = "singstar_mic2_capture";
            "target.object" = "singstar_raw";
            "stream.dont-remix" = true;
            "audio.position" = [ "FR" ];
          };
          "playback.props" = {
            "node.name" = "singstar_mic2";
            "media.class" = "Audio/Source/Virtual";
            "audio.position" = [ "MONO" ];
          };
        };
      }
    ];
  };
in
{
  options.services.karaoke.audio = {
    enable = lib.mkEnableOption "PipeWire + SingStar mic config";

    stubSource = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Create a virtual stereo source named "singstar_raw" so the channel
        split has something to attach to without real SingStar hardware.
        VM-only — leave off on the appliance.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Rename SingStar's ALSA source to a stable name so the loopback split can
    # target it without depending on the kernel-generated alsa_input.usb-...
    # node name. SingStar wireless mic dongle: USB 1415:0020.
    services.pipewire.wireplumber.extraConfig."10-singstar-rename" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "device.vendor.id" = "0x1415"; "device.product.id" = "0x0020"; }
          ];
          actions.update-props = {
            "device.description" = "SingStar Mics";
          };
        }
      ];
      "node.rules" = [
        {
          matches = [
            {
              "device.vendor.id" = "0x1415";
              "device.product.id" = "0x0020";
              "media.class" = "Audio/Source";
            }
            { "node.name" = "~alsa_input\\.usb-.*USBMIC.*"; }
          ];
          actions.update-props = {
            "node.name" = "singstar_raw";
            "node.description" = "SingStar (raw stereo)";
          };
        }
      ];
    };

    services.pipewire.extraConfig.pipewire."20-singstar-split" = singstarSplit;

    # VM-only: synthesise a stereo "singstar_raw" so the split modules attach
    # and `pactl list sources` shows two named mono sources for eval.
    services.pipewire.extraConfig.pipewire."05-singstar-stub" =
      lib.mkIf cfg.stubSource {
        "context.objects" = [
          {
            factory = "adapter";
            args = {
              "factory.name" = "support.null-audio-sink";
              "node.name" = "singstar_raw";
              "node.description" = "SingStar (stub)";
              "media.class" = "Audio/Source/Virtual";
              "audio.position" = [ "FL" "FR" ];
            };
          }
        ];
      };
  };
}
