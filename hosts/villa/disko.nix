{ ... }:
let
  btrfsOpts = [ "noatime" "compress=zstd:1" ];
in
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-Corsair_MP600_MINI_A66HB33502Z9VB";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };

        cryptroot = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            settings.allowDiscards = true;
            extraFormatArgs = [ "--type" "luks2" "--pbkdf" "argon2id" ];

            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = btrfsOpts;
                };
                "@blank" = { };

                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = btrfsOpts;
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = btrfsOpts;
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = btrfsOpts;
                };
                "@root" = {
                  mountpoint = "/root";
                  mountOptions = btrfsOpts;
                };
                "@srv" = {
                  mountpoint = "/srv";
                  mountOptions = btrfsOpts;
                };
                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = btrfsOpts;
                };
                "@cache" = {
                  mountpoint = "/var/cache";
                  mountOptions = btrfsOpts;
                };
                "@tmp" = {
                  mountpoint = "/var/tmp";
                  mountOptions = btrfsOpts;
                };

                # Placeholder for hibernation. A btrfs swapfile needs its own
                # NOCOW subvolume, so reserving it now costs nothing and saves
                # a reformat later. Wiring up resume= is a separate step --
                # see disko's btrfs `swap` support before committing to it.
                "@swap" = {
                  mountpoint = "/swap";
                  mountOptions = [ "noatime" ];
                };
              };
            };
          };
        };
      };
    };
  };

  # No hibernate yet, so zram covers the 16G of soldered LPDDR3.
  zramSwap.enable = true;
}
