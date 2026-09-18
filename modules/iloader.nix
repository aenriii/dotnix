{ lib, pkgs, inputs, config, ... }:
let
  cfg = config.dotnix.iloader;
in {
  options.dotnix.iloader = {
    enable = lib.mkEnableOption "iloader";
  };
  config = lib.mkIf (cfg.enable) {
    services.usbmuxd.enable = lib.mkDefault true;
    environment.systemPackages = [ pkgs.iloader ];
  };
}