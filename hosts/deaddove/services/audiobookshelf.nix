{ ... }:
let
  audiobooks = "/share/media/Audiobooks";
  uid = 2004;
in
{
  imports = [
    (import ./tailnet-container.nix {
      name = "audiobooks";
      hostName = "audiobooks";
      shared = true;
      subnet = 7;
      port = 8000;
      bindMounts = {
        "/audiobooks" = {
          hostPath = audiobooks;
          isReadOnly = true;
        };
        # config, metadata, covers and the sqlite db all live here
        "/var/lib/audiobookshelf" = {
          hostPath = "/persist/audiobookshelf/data";
          isReadOnly = false;
        };
      };
      container = {
        users.users.audiobookshelf.uid = uid;
        users.groups.audiobookshelf.gid = uid;

        services.audiobookshelf = {
          enable = true;
          host = "127.0.0.1";
          port = 8000;
        };
      };
    })
  ];

  systemd.tmpfiles.rules = [
    "d /persist/audiobookshelf/data 0700 ${toString uid} ${toString uid} -"
  ];

  systemd.services."container@audiobooks".unitConfig.RequiresMountsFor = [ audiobooks ];
}
