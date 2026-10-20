{ config, ... }:
let
  downloads = "/share/incoming/soulseek";
  musicFolder = "/share/media/music";
  uid = 2001;
in
{
  sops.secrets.slskd-env = {
    sopsFile = ./secrets/slskd.env;
    format = "dotenv";
  };

  imports = [
    (import ./tailnet-container.nix {
      name = "slskd";
      hostName = "slsk";
      subnet = 4;
      port = 5030;
      bindMounts = {
        "/downloads" = {
          hostPath = downloads;
          isReadOnly = false;
        };
        "/music" = {
          hostPath = musicFolder;
          isReadOnly = true;
        };
        "/var/lib/slskd" = {
          hostPath = "/persist/slskd/data";
          isReadOnly = false;
        };
        "/run/secrets/slskd.env" = {
          hostPath = config.sops.secrets.slskd-env.path;
          isReadOnly = true;
        };
      };
      container = {
        users.users.slskd = {
          inherit uid;
        };

        services.slskd = {
          enable = true;
          # run with users as the primary group so downloads land as
          # 2001:users and the rest of us can tidy up incoming
          group = "users";
          openFirewall = true;
          environmentFile = "/run/secrets/slskd.env";
          settings = {
            directories = {
              downloads = "/downloads/complete";
              incomplete = "/downloads/incomplete";
            };
            shares.directories = [ "/music" ];
            web.port = 5030;
          };
        };

        # ReadWritePaths entries have to exist or the unit won't start
        systemd.tmpfiles.rules = [
          "d /downloads/complete 0775 - users -"
          "d /downloads/incomplete 0775 - users -"
          # catch anything still owned by the old slskd group
          "Z /downloads - - users -"
        ];
        # ntfs3 keeps the mode we create things with, and we only get in
        # through the group
        systemd.services.slskd.serviceConfig.UMask = "0002";
      };
    })
  ];

  systemd.tmpfiles.rules = [
    "d /persist/slskd/data 0700 ${toString uid} ${toString uid} -"
  ];

  systemd.services."container@slskd".unitConfig.RequiresMountsFor = [
    downloads
    musicFolder
  ];
}
