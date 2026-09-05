{ ... }:
let
  # `ssd` and `space_cache=v2` are autodetected on modern kernels; don't restate them.
  btrfsOpts = [ "noatime" "compress=zstd:1" ];
in
{
  disko.devices.disk.main = {
    type = "disk";
    # Samsung 870 EVO 1TB, firmware SVT03B6Q. Currently holds the Windows
    # install -- running disko in destroy/format mode wipes it.
    device = "/dev/disk/by-id/ata-Samsung_SSD_870_EVO_1TB_S75BNS0W512743W";
    content = {
      type = "gpt";
      partitions = {
        # Must exist: /boot currently lives on the MP600, which leaves for
        # villa. Without this deaddove has no bootloader after the swap.
        # 4G because lanzaboote keeps a signed image per generation here.
        ESP = {
          priority = 1;
          size = "4G";
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
            # SATA SSD: pass discards through so fstrim reaches the drive.
            # Tradeoff: leaks used-block counts to anyone holding the disk.
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
                # Empty on purpose -- dotnix.persistence.wipe = "btrfs-rollback"
                # restores @ from this. Never snapshot a populated @ into it.
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
                # ~401G. Puts the pool around 82% once everything migrates;
                # fine for btrfs, but there's no growth room left.
                "@games" = {
                  mountpoint = "/home/aenri/Games";
                  mountOptions = btrfsOpts;
                };
              };
            };
          };
        };
      };
    };
  };

  # SATA SSDs benefit from this more than NVMe does.
  services.fstrim.enable = true;

  # Matches the current setup: zram only, no disk swap.
  zramSwap.enable = true;
}
