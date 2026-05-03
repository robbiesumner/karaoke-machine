{ config, lib, pkgs, ... }:
let
  cfg = config.services.karaoke.kiosk;

  # Kiosk session entry point. cage launches this once; the inner loop respawns
  # USDX on crash without tearing down Wayland.
  karaokeSession = pkgs.writeShellApplication {
    name = "karaoke-session";
    runtimeInputs = with pkgs; [ ultrastardx wlr-randr coreutils gawk ];
    text = ''
      # SDL3 (via sdl2-compat) prefers X11 unless told otherwise. Use native
      # Wayland — avoids Xwayland teardown crashes that ABRT cage on USDX exit.
      export SDL_VIDEODRIVER=wayland

      # Force 1080p. USDX (SDL) scales weirdly on 4K panels.
      output=$(wlr-randr | awk '/^[^[:space:]]/ {print $1; exit}')
      if [ -n "''${output:-}" ]; then
        wlr-randr --output "$output" --mode 1920x1080@60Hz || true
      fi

      # Relaunch loop — never let the session end. Exiting would expose
      # cage's empty root or, worse, drop back to a TTY.
      # -songpath points USDX at the Samba-shared songs dir so drops via
      # \\karaoke\songs are picked up on the next R-rescan.
      while true; do
        ultrastardx -songpath ${cfg.songPath} || true
        sleep 1
      done
    '';
  };
in
{
  options.services.karaoke.kiosk = {
    enable = lib.mkEnableOption "USDX kiosk session";

    songPath = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/karaoke/songs";
      description = ''
        Directory passed to USDX as -songpath. Should match the Samba share
        path so drops via the network share are visible to the engine.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.karaoke = {
      isNormalUser = true;
      description = "Karaoke kiosk";
      # Passwordless. Account is autologin-only; no password prompt anywhere.
      hashedPassword = "";
      extraGroups = [ "audio" "video" "input" ];
    };

    # cage = single-client Wayland kiosk. cage exec's the session script;
    # the inner shell loop respawns USDX without tearing down Wayland. If
    # cage itself crashes (e.g. Xwayland teardown bug), systemd respawns it.
    services.cage = {
      enable = true;
      user = "karaoke";
      program = lib.getExe karaokeSession;
    };

    systemd.services."cage-tty1".serviceConfig = {
      Restart = "always";
      RestartSec = "1s";
    };

    # USDX needs OpenGL for SDL rendering under Wayland.
    hardware.graphics.enable = true;
  };
}
