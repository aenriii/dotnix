{ pkgs, lib, ... }:
{
  imports = [
    ./aenri/options.nix
    ./aenri/sandbox.nix
    ./aenri/scripts
    ./aenri/configs
  ];

  home = {
    username = "aenri";
    stateVersion = "25.11";

    homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/aenri" else "/home/aenri";
    sessionVariables = {
      EDITOR = "nvim";
    } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      LIBVIRT_DEFAULT_URI = "qemu:///system";
    };
    # noctalia's avatar_path points at ~/.face
    file.".face".source = ./aenri/assets/.face.png;
    file.".config/nix/nix.conf".text = "experimental-features = nix-command flakes";
  };
}
