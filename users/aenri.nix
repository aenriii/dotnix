{ ... }:
{
  imports = [
    ./aenri/options.nix
    ./aenri/sandbox.nix
    ./aenri/scripts
    ./aenri/configs
  ];

  home = {
    username = "aenri";
    homeDirectory = "/home/aenri";
    # home-manager requires this; it is NOT the same as system.stateVersion.
    stateVersion = "25.11";

    sessionVariables = {
      EDITOR = "nvim"; # provided by configs/dev.nix
      LIBVIRT_DEFAULT_URI = "qemu:///session";
    };

    # noctalia's avatar_path points at ~/.face
    file.".face".source = ./aenri/assets/.face.png;
  };
}
