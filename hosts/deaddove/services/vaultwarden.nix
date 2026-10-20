{ config, ... }:
let
  domain = "vault.gentoo-danio.ts.net";
  vaultwardenUid = 996;
  vaultwardenGid = 996;
in
{
  sops.secrets.vaultwarden-env = {
    sopsFile = ./secrets/vaultwarden.env;
    format = "dotenv";
  };

  imports = [
    (import ./tailnet-container.nix {
      name = "vaultwarden";
      hostName = "vault";
      subnet = 2;
      port = 8000;
      stateVersion = "25.11";
      bindMounts = {
        "/var/lib/vaultwarden" = {
          hostPath = "/persist/vaultwarden/data";
          isReadOnly = false;
        };
        "/var/backup/vaultwarden" = {
          hostPath = "/persist/vaultwarden/backup";
          isReadOnly = false;
        };
        "/run/secrets/vaultwarden-env" = {
          hostPath = config.sops.secrets.vaultwarden-env.path;
          isReadOnly = true;
        };
      };
      container = {
        users.users.vaultwarden.uid = vaultwardenUid;
        users.groups.vaultwarden.gid = vaultwardenGid;

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
      };
    })
  ];

  systemd.tmpfiles.rules = [
    "d /persist/vaultwarden/data 0700 ${toString vaultwardenUid} ${toString vaultwardenGid} -"
    "d /persist/vaultwarden/backup 0700 ${toString vaultwardenUid} ${toString vaultwardenGid} -"
  ];
}
