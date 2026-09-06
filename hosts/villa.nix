{ pkgs, inputs, ... }:
{
  imports = [
    ./villa/disko.nix
    ./villa/hardware.nix
  ];

  programs.niri.enable = true;
  programs.niri.package = pkgs.niri;

  nixpkgs.config.allowUnfree = true;
  nix.settings.allowed-users = [ "aenri" ];
  nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 30d"; };
  nix.optimise.automatic = true;

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  programs.zsh.enable = true;
  
  networking.hostName = "villa";
  time.timeZone = "America/Indiana/Indianapolis";
  system.stateVersion = "26.05";

  pyria = {
    enable = true;
    kernel = {
      enable = true;
      flavor = "mainline";
      config = "hardened";
    };
    security = {
      network = {
        dot.enable = true;
        tailscale.enable = true;
      };
      apparmor.enable = false; # incomplete
      audit.enable = true;
      allocator.enable = true;
    };
  };
  users.users.aenri = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    shell = pkgs.zsh;
  };
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";

    extraSpecialArgs = { inherit inputs; };

    users.aenri.imports = [
      ../users/aenri.nix
      ../users/aenri/configs/desktop
      ../users/aenri/configs/gaming
    ];
  };

  dotnix = {
    greeter = {
      enable = true;
      sync-users = [ "aenri" ];
      settings = {
        session.default = "niri";
        keyboard.layout = "us";
        cursor = { theme = "capitaine-cursors"; size = 24; };
      };
    };
    network = {
      enable = true;
      bluetooth = true;
      tailscale = {
        enable = true;
        exitNodeProtection = true;
        caddy = true;
      };
    };
  };
}