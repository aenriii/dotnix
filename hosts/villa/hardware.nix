{ config, lib, ... }:
{
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "sd_mod"
    "thunderbolt"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Intel 8265 wifi needs redistributable firmware to associate at all.
  hardware.enableRedistributableFirmware = true;

  hardware.graphics.enable = true;

  # Kaby Lake R throttles hard without this.
  services.thermald.enable = true;

  # Lenovo ships UEFI capsule updates for this model through LVFS.
  services.fwupd.enable = true;

  # Trackpoint + trackpad.
  services.libinput.enable = true;
  hardware.trackpoint = {
    enable = true;
    emulateWheel = true;
  };

  # Fingerprint reader is a Synaptics unit that only works with a
  # proprietary blob and is unreliable on Linux -- left off deliberately,
  # and it's the wrong trust anchor for a pyria host anyway.
  # services.fprintd.enable = false;

  powerManagement.enable = true;

  # IMPORTANT, and not something Nix can set for you:
  # this generation defaults its BIOS sleep state to "Windows 10" (S0ix /
  # Modern Standby), which on Linux drains the battery flat in a closed bag.
  # In BIOS -> Config -> Power, set "Sleep State" to "Linux" for real S3.
}
