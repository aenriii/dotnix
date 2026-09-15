{ ... }:
let
  btrfsOpts = [ "noatime" "compress=zstd:1" ];
in
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/ata-Samsung_SSD_870_EVO_1TB_S75BNS0W512743W";
    content = {
      type = "gpt";
      partitions = {
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
                "@games" = {
                  mountpoint = "/home/aenri/Games";
                  mountOptions = btrfsOpts ++ [
                    "X-mount.owner=aenri"
                    "X-mount.group=users"
                  ];
                };
                "@vms" = {
                  mountpoint = "/home/aenri/VMs";
                  mountOptions = btrfsOpts ++ [
                    "X-mount.owner=aenri"
                    "X-mount.group=users"
                  ];
                };
              };
            };
          };
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "z /home/aenri/Games 0755 aenri users -"
  ];

  services.fstrim.enable = true;

  zramSwap.enable = true;
}
