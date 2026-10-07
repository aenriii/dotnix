{ config, lib, pkgs, ... }:
{
  # Dell Latitude 5421 -- i7-11850H (Tiger Lake-H), 24G DDR4.
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "vmd"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Intel AX201/AX210 wifi and the Xe iGPU's GuC/HuC both need
  # redistributable firmware.
  hardware.enableRedistributableFirmware = true;

  # Tiger Lake Xe graphics: iHD for VA-API, VPL runtime for QSV.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # 45W H-series part in a thin chassis; thermald keeps it from bouncing
  # off the thermal limit.
  services.thermald.enable = true;

  # Dell ships BIOS, TB and dock firmware through LVFS.
  services.fwupd.enable = true;

  # Touchpad, plus the pointing stick on models that have one
  # (harmless if it's absent).
  services.libinput.enable = true;
  hardware.trackpoint = {
    enable = true;
    emulateWheel = true;
  };

  # The optional fingerprint reader sits behind Broadcom ControlVault,
  # which has no usable Linux support -- left off deliberately, and it's
  # the wrong trust anchor for a pyria host anyway.
  # services.fprintd.enable = false;

  powerManagement.enable = true;

  # IMPORTANT, and not something Nix can set for you:
  # - Tiger Lake Dells only do S0ix (s2idle); there's no S3 toggle in BIOS.
  #   It works on Linux, but expect some drain while suspended.
  # - If the NVMe doesn't show up in the installer, the BIOS has
  #   "RAID On" (Intel VMD) set. "vmd" above handles it, but switching
  #   Storage -> SATA/NVMe Operation to "AHCI/NVMe" is simpler.
}
