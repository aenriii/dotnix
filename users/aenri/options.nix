{ lib, ... }:
{
  options.dotnix.home = {
    gui = lib.mkEnableOption "desktop programs and their configuration";
    gaming = lib.mkEnableOption "steam and friends";
    gl-compat = lib.mkEnableOption "nixGL compat for gaming off nixOS";
    virt = lib.mkEnableOption "libvirt domains";
  };
}