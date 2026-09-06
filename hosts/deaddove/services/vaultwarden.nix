{ config, pkgs, ... }:
let
  containerAddress = "10.233.2.2";
  domain = "vault.gentoo-danio.ts.net";
in
{
  sops.secrets.vaultwarden-env = {
    sopsFile = ./secrets/vaultwarden.env;
    format = "dotenv";
  };
  sops.secrets.vaultwarden-tailscale-authkey = {
    sopsFile = ./secrets/tailscale-authkey;
    format = "binary";
  };

  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-vaultwarden" ];
  };

  systemd.tmpfiles.rules = [
    "d /persist/vaultwarden/data 0700 root root -"
    "d /persist/vaultwarden/backup 0700 root root -"
    "d /persist/vaultwarden/tailscale-state 0700 root root -"
  ];

  containers.vaultwarden = {
    autoStart = true;
    ephemeral = true; 

    privateNetwork = true;
    hostAddress = "10.233.2.1";
    localAddress = containerAddress;
    enableTun = true; 

    bindMounts = {
      "/var/lib/vaultwarden" = {
        hostPath = "/persist/vaultwarden/data";
        isReadOnly = false;
      };
      "/var/backup/vaultwarden" = {
        hostPath = "/persist/vaultwarden/backup";
        isReadOnly = false;
      };
      "/var/lib/tailscale" = {
        hostPath = "/persist/vaultwarden/tailscale-state";
        isReadOnly = false;
      };
      "/run/secrets/vaultwarden-env" = {
        hostPath = config.sops.secrets.vaultwarden-env.path;
        isReadOnly = true;
      };
      "/run/secrets/tailscale-authkey" = {
        hostPath = config.sops.secrets.vaultwarden-tailscale-authkey.path;
        isReadOnly = true;
      };
    };

    config =
      { pkgs, ... }:
      {
        system.stateVersion = "25.11";

        networking.firewall.enable = true;

        networking.hostName = "vault";

        networking.nameservers = [
          "1.1.1.1"
          "9.9.9.9"
        ];

        services.tailscale = {
          enable = true;
          authKeyFile = "/run/secrets/tailscale-authkey";
          extraUpFlags = [ "--accept-dns=false" ];
        };

        systemd.services.tailscaled-autoconnect.serviceConfig = {
          TimeoutStartSec = "15s";
          Restart = "on-failure";
          RestartSec = "5s";
        };

        services.vaultwarden = {
          enable = true;
          backupDir = "/var/backup/vaultwarden";
          environmentFile = [ "/run/secrets/vaultwarden-env" ];
          config = {
            DOMAIN = "https://${domain}";
            ROCKET_ADDRESS = "127.0.0.1";
            ROCKET_PORT = 8000;
            SIGNUPS_ALLOWED = false;
            WEBSOCKET_ENABLED = true;
          };
        };

        systemd.services.vaultwarden-tailscale-serve = {
          description = "Publish vaultwarden via tailscale serve";
          after = [
            "tailscaled-autoconnect.service"
            "vaultwarden.service"
          ];
          wants = [ "tailscaled-autoconnect.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            Restart = "on-failure";
            RestartSec = "5s";
            ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg 8000";
            ExecStop = "${pkgs.tailscale}/bin/tailscale serve reset";
          };
        };
      };
  };
}
