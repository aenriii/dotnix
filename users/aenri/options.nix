{ lib, ... }:
{
  options.dotnix.home = {
    gui = lib.mkEnableOption "desktop programs and their configuration";
    gaming = lib.mkEnableOption "steam and friends";
    gl-compat = lib.mkEnableOption "nixGL compat for gaming off nixOS";
    virt = lib.mkEnableOption "libvirt domains";

    git.signing = {
      format = lib.mkOption {
        type = lib.types.enum [ "openpgp" "ssh" ];
        default = "openpgp";
        description = "signature format git uses for this host";
      };
      key = lib.mkOption {
        type = lib.types.str;
        default = "CC3624C1D78F4FEDD7522A22EC3014D92E7084DA";
        description = "gpg key id, or ssh public key / path to one";
      };
    };
  };
}