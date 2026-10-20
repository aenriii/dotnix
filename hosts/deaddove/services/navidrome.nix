{ ... }:
let
  musicFolder = "/share/media/music";
  uid = 2000;
in
{
  imports = [
    (import ./tailnet-container.nix {
      name = "navidrome";
      hostName = "music";
      shared = true;
      subnet = 3;
      port = 4533;
      bindMounts = {
        "/music" = {
          hostPath = musicFolder;
          isReadOnly = true;
        };
        "/var/lib/navidrome" = {
          hostPath = "/persist/navidrome/data";
          isReadOnly = false;
        };
      };
      container = {
        users.users.navidrome.uid = uid;
        users.groups.navidrome.gid = uid;

        services.navidrome = {
          enable = true;
          settings = {
            Address = "127.0.0.1";
            Port = 4533;
            MusicFolder = "/music";
            EnableInsightsCollector = false;
          };
        };
      };
    })
  ];

  systemd.tmpfiles.rules = [
    "d /persist/navidrome/data 0700 ${toString uid} ${toString uid} -"
  ];

  systemd.services."container@navidrome".unitConfig.RequiresMountsFor = [ musicFolder ];
}
