{ lib, pkgs, config, ... }:
let
  cfg = config.dotnix.librepods;
in {
  options.dotnix.librepods = {
    enable = lib.mkEnableOption "librepods (rust rewrite) for airpods";
    spoofAppleVendorId = lib.mkEnableOption ''
      announcing apple's bluetooth vendor id (0x004C) from bluez.
      unlocks multipoint handoff and hearing aid settings on airpods,
      but changes how this machine identifies itself to every bluetooth device.
      re-pair the airpods after toggling this
    '';
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.librepods ];

    hardware.bluetooth.settings.General = lib.mkIf cfg.spoofAppleVendorId {
      DeviceID = "bluetooth:004C:0000:0000";
    };

    # lets airpods stem presses reach mpris (play/pause/skip).
    # don't also run mpris-proxy, it fights wireplumber over this
    services.pipewire.wireplumber.extraConfig."51-bluez-avrcp" = {
      "monitor.bluez.properties"."bluez5.dummy-avrcp-player" = true;
    };
  };
}
