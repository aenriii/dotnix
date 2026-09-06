{ lib,
  config,
  ...
}:
let 
  cfg = config.dotnix.network;
in 
{
  options.dotnix.network = {
    enable = lib.mkEnableOption "default network configurations";
    bluetooth = lib.mkEnableOption "bluetooth";
    tailscale = {
      enable = lib.mkEnableOption "tailscale";
      exitNodeProtection = lib.mkEnableOption "nixos specific tailscale fix for users of exit nodes";
      caddy = lib.mkEnableOption "allow caddy to edit certs";
    };
  };
  config = lib.mkIf (cfg.enable) {
    services.tailscale = {
      enable = lib.mkDefault cfg.tailscale.enable;
      permitCertUid = lib.mkIf (cfg.tailscale.caddy) (lib.mkDefault "caddy");
    };
    networking.nftables.enable = cfg.enable;
    networking.firewall = {
      enable = cfg.enable;
      trustedInterfaces = [ config.services.tailscale.interfaceName ];
      allowedUDPPorts = [ config.services.tailscale.port ];
      checkReversePath = lib.mkIf (cfg.tailscale.exitNodeProtection) (lib.mkDefault "loose") ;
    };
  
    networking.networkmanager.enable = cfg.enable;
    
    networking.networkmanager.unmanaged = [ "interface-name:ve-*" ];
    
    systemd = lib.mkIf cfg.tailscale.enable {
      services.tailscaled.serviceConfig.Environment = [
        "TS_DEBUG_FIREWALL_MODE=nftables"
      ];
      network.wait-online.enable = false;
    };
    
    boot.initrd.systemd.network.wait-online.enable = lib.mkDefault cfg.tailscale.enable;
    hardware.bluetooth.enable = cfg.bluetooth;
    
  };
}