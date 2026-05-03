{ config, lib, pkgs, ... }:
{
  options.services.karaoke.networking.enable = lib.mkEnableOption "NetworkManager + avahi (mDNS)";

  config = lib.mkIf config.services.karaoke.networking.enable {
    # NetworkManager owns WiFi + ethernet. Picked over systemd-networkd because
    # the first-boot wizard (S5) drops .nmconnection files for SSID/PSK.
    networking.networkmanager.enable = true;

    # Resolve `\\karaoke.local\songs` on typical home LANs without needing the
    # router to run DNS. nssmdns4 wires .local into glibc so smbd/clients see
    # the same names. openFirewall handles 5353/udp.
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
        userServices = true;
      };

      # Advertise the songs share so the kiosk shows up under Finder's
      # "Network" sidebar on macOS without typing a UNC path.
      extraServiceFiles.smb = ''
        <?xml version="1.0" standalone='no'?>
        <!DOCTYPE service-group SYSTEM "avahi.dtd">
        <service-group>
          <name replace-wildcards="yes">%h</name>
          <service>
            <type>_smb._tcp</type>
            <port>445</port>
          </service>
        </service-group>
      '';
    };

    # Some home routers block mDNS multicast. tty1 is owned by the kiosk
    # session, so the owner can flip to tty2 (Ctrl+Alt+F2) and read the
    # current IPv4 from the login banner as a fallback. \4 is agetty's
    # IPv4-of-first-interface escape; \n is the kernel nodename.
    services.getty.helpLine = lib.mkAfter ''

      Songs share: smb://\4/songs
                   smb://\n.local/songs  (if mDNS works)
    '';
  };
}
