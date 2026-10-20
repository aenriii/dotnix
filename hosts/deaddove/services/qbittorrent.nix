{ ... }:
let
  downloads = "/share/incoming/torrent";
  uid = 2002;
  exitNode = "us-chi-wg-301.mullvad.ts.net";
in
{
  imports = [
    (import ./tailnet-container.nix {
      name = "qbittorrent";
      hostName = "torrent";
      subnet = 5;
      port = 8080;
      bindMounts = {
        "/downloads" = {
          hostPath = downloads;
          isReadOnly = false;
        };
        "/var/lib/qBittorrent" = {
          hostPath = "/persist/qbittorrent/data";
          isReadOnly = false;
        };
      };
      container = {
        users.users.qbittorrent = {
          inherit uid;
          extraGroups = [ "users" ];
        };
        users.groups.qbittorrent.gid = uid;

        services.tailscale = {
          useRoutingFeatures = "client";
          extraSetFlags = [ "--exit-node=${exitNode}" ];
        };

        systemd.services.qbittorrent = {
          # only once the exit node is set
          requires = [ "tailscaled-set.service" ];
          after = [ "tailscaled-set.service" ];
          # ntfs3 keeps the mode we create things with, and we only get in
          # through the group
          serviceConfig.UMask = "0002";
        };

        services.qbittorrent = {
          enable = true;
          webuiPort = 8080;
          serverConfig = {
            LegalNotice.Accepted = true;
            BitTorrent.Session = {
              DefaultSavePath = "/downloads";
              TempPathEnabled = true;
              TempPath = "/downloads/.incomplete";
              Interface = "tailscale0";
              InterfaceName = "tailscale0";
            };
            Preferences = {
              General.Locale = "en";
              WebUI.LocalHostAuth = false;
            };
          };
        };
      };
    })
  ];

  systemd.tmpfiles.rules = [
    "d /persist/qbittorrent/data 0700 ${toString uid} ${toString uid} -"
  ];

  systemd.services."container@qbittorrent".unitConfig.RequiresMountsFor = [ downloads ];
}
