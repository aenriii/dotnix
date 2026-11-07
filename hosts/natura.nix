{ inputs, pkgs, ... }:
{
  imports = [
    ./natura/apps.nix
  ];

  networking = {
    hostName = "natura";
    computerName = "natura";
  };
  system = {
    primaryUser = "aenri";
    stateVersion = 6;
  };
  nix-homebrew = {
    enable = true;
    user = "aenri";
    mutableTaps = false;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
    };
  };
  system.defaults = {
    dock.autohide = true;
    finder.AppleShowAllExtensions = true;
    NSGlobalDomain.KeyRepeat = 2;
    # …
  };
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";

    extraSpecialArgs = { inherit inputs; };

    users.aenri.imports = [
      ../users/aenri.nix
      ../users/aenri/configs/desktop
    ];
  };
  
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  users.users.aenri.home = "/Users/aenri";
  programs.zsh.enable = true;
  security.pam.services.sudo_local.touchIdAuth = true;
  services.tailscale.enable = true;
}