# printing.nix — home printer + scanner (Canon PIXMA G3411), both reached over
# the network, so they are shared by every host.
{ lib, pkgs, ... }:

{
  # Enable CUPS to print documents.
  services.printing = {
    enable = true;

    # IMPORTANT: Do NOT use below driver for Canon Pixma G3411 - IPP Everywhere is better.
    #drivers = [ pkgs.cnijfilter2 ];
  };

  # Don't fail system activation when the printer is offline.
  systemd.services.ensure-printers.wantedBy = lib.mkForce [ ];

  # Service required to locate printers/scanners in the network.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Home printer - Canon PIXMA G3411.
  hardware.printers = {
    ensurePrinters = [
      {
        name = "Canon_G3010_series";
        model = "everywhere";
        location = "home";
        deviceUri = "ipp://192.168.1.183/ipp/print";
      }
    ];
  };

  # Support for scanner devices.
  # NOTE: Example command `scanimage --device-name "airscan:w0:Canon G3010" --format=png --resolution 600 > scan.png`.
  hardware.sane = {
    enable = true;

    extraBackends = [
      pkgs.sane-airscan # Used for PIXMA G3411.

      # Pin the scanner to a static device instead of relying on discovery.
      #
      # Why: the PIXMA G3411 does NOT advertise eSCL/AirScan (no _uscan._tcp over
      # mDNS), so sane-airscan can only reach the scanner via WSD. It has no WSD
      # mDNS record either, so airscan bootstraps from the printer's _ipp (IPP
      # print) mDNS record as a "hint", then sends a directed WSD probe. That
      # creates TWO internal entries that race for a device-id slot: a throwaway
      # mDNS-hint entry (UUID from the IPP record, can't scan, discarded) and the
      # real WSD entry. Whichever is created first takes slot 0, so the auto name
      # flips between "airscan:w0:..." and "airscan:w1:..." between runs - and can
      # even change between `scanimage -L` and the actual scan, breaking scripts.
      #
      # Fix: declare the WSD scan endpoint statically and turn discovery off. With
      # no discovery there is no race, the name is deterministic (always w0), and
      # scanning no longer depends on flaky WSD/mDNS timing. This does NOT affect
      # printing: that goes through CUPS/IPP (hardware.printers above) and mDNS,
      # which are untouched - `discovery = disable` only scopes sane-airscan.
      #
      # Endpoint/IP match the print queue above; if the printer's IP ever changes,
      # update both (or swap in the mDNS hostname http://drukara.local:80/...).
      # Placed after pkgs.sane-airscan so mkSaneConfig's last-wins merge lets this
      # airscan.conf override the backend's empty default.
      (pkgs.writeTextDir "etc/sane.d/airscan.conf" ''
        [devices]
        "Canon G3010" = http://192.168.1.183:80/wsd/scanservice.cgi, WSD

        [options]
        discovery = disable
      '')
    ];
  };
}
