{ pkgs, inputs, ... }:
{
  imports = [
    ../modules
    ./villa/disko.nix
    ./villa/hardware.nix
  ];
  nixpkgs.config.allowUnfree = true;
  networking.hostName = "villa";
  time.timeZone = "America/Indiana/Indianapolis";
  system.stateVersion = "26.05";
  
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
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
    librepods = {
      enable = true;
      spoofAppleVendorId = true;
    };
  };
  nix = {
    settings = {
      allowed-users = [ "aenri" ];
      builders-use-substitutes = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    optimise.automatic = true;
    distributedBuilds = true;
    buildMachines = [{
      hostName = "deaddove.gentoo-danio.ts.net";
      sshUser = "nixremote";
      sshKey = "/root/.ssh/nixremote";
      protocol = "ssh-ng";
      systems = [ "x86_64-linux" "i686-linux" ];
      maxJobs = 8;
      speedFactor = 2;
      supportedFeatures = [ "benchmark" "big-parallel" "kvm" "nixos-test" ];
      publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSVA3eUpya3NubTBLQkxDb3Q5dGhXaDlONnl1TXE3TWRSdkl3RURsMUpkUnggcm9vdEBkZWFkZG92ZQo=";
    }];
  };
  programs = {
    zsh.enable = true;
    niri = {
      enable = true;
      package = pkgs.niri;
    };
    neovim = { 
      enable = true; 
      defaultEditor = true; 
    };
  };
}
