{ ... }:
let
  movies = "/share/media/movies";
  shows = "/share/media/shows";
  uid = 2003;
  # stable name so it doesn't matter which renderD* the rx 7600 probes as.
  # not the by-path link: nspawn splits --bind on ':' and chokes on the pci id
  amdRender = "/dev/dri/rx7600-render";
in
{
  imports = [
    (import ./tailnet-container.nix {
      name = "jellyfin";
      hostName = "jellyfin";
      shared = true;
      subnet = 6;
      port = 8096;
      allowedDevices = [
        {
          node = "char-drm";
          modifier = "rw";
        }
      ];
      bindMounts = {
        "/dev/dri/renderD128" = {
          hostPath = amdRender;
          isReadOnly = false;
        };
        "/media/movies" = {
          hostPath = movies;
          isReadOnly = true;
        };
        "/media/shows" = {
          hostPath = shows;
          isReadOnly = true;
        };
        "/var/lib/jellyfin" = {
          hostPath = "/persist/jellyfin/data";
          isReadOnly = false;
        };
        "/var/cache/jellyfin" = {
          hostPath = "/persist/jellyfin/cache";
          isReadOnly = false;
        };
      };
      container = {
        users.users.jellyfin.uid = uid;
        users.groups.jellyfin.gid = uid;

        # mesa's radeonsi vaapi driver
        hardware.graphics.enable = true;

        services.jellyfin = {
          enable = true;
          # only seeds encoding.xml on first start, the dashboard owns it after
          hardwareAcceleration = {
            enable = true;
            type = "vaapi";
            device = "/dev/dri/renderD128";
          };
          transcoding = {
            enableHardwareEncoding = true;
            # what vcn 4 can do
            hardwareDecodingCodecs = {
              h264 = true;
              hevc = true;
              hevc10bit = true;
              vp9 = true;
              av1 = true;
            };
            hardwareEncodingCodecs = {
              hevc = true;
              av1 = true;
            };
          };
        };
      };
    })
  ];

  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="renderD*", KERNELS=="0000:28:00.0", SYMLINK+="dri/rx7600-render"
  '';

  systemd.tmpfiles.rules = [
    "d /persist/jellyfin/data 0700 ${toString uid} ${toString uid} -"
    "d /persist/jellyfin/cache 0700 ${toString uid} ${toString uid} -"
  ];

  systemd.services."container@jellyfin".unitConfig.RequiresMountsFor = [
    movies
    shows
  ];
}
