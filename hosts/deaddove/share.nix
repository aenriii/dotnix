{ ... }:
{
  fileSystems."/share" = {
    device = "/dev/disk/by-id/ata-WDC_WD40EZRZ-00GXCB0_WD-WCC7K3DDDNSK-part4";
    fsType = "ntfs3";
    options = [
      "noatime"
      "nofail"
      "x-systemd.device-timeout=10s"
      "uid=1000"
      "gid=100"
      "umask=022"
    ];
  };
}
