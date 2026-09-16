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
    stateVersion = "25.11";

    sessionVariables = {
      EDITOR = "nvim"; 
      LIBVIRT_DEFAULT_URI = "qemu:///system";
    };

    # noctalia's avatar_path points at ~/.face
    file.".face".source = ./aenri/assets/.face.png;
    file.".config/nix/nix.conf".text = "experimental-features = nix-command flakes";
  };
}
