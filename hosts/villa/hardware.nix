{ config, lib, pkgs, ... }:
{
  boot = {
    initrd = {
      kernelModules = [ ];
      availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "vmd"
        "nvme"
        "usb_storage"
        "sd_mod"
        "rtsx_pci_sdmmc"
      ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };
  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        vpl-gpu-rt
      ];
    };
    trackpoint = {
      enable = true;
      emulateWheel = true;
    };
  };
  services = {
    thermald.enable = true;
    fwupd.enable = true;
    libinput.enable = true;
  };
  
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
  powerManagement.enable = true;
}
