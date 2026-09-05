{ pkgs, inputs, ... }:
{
  imports = [
    ../modules
    ./deaddove/disko.nix
    ./deaddove/hardware.nix
  ];

  hardware.enableRedistributableFirmware = true;

  hardware.graphics.enable32Bit = true;

  programs.niri.enable = true;
  programs.niri.package = pkgs.niri;

  # Left off for the first install, per the staged plan: get a bootable system
  # first, then turn this on with wipe = "none" and live on it before enabling
  # the rollback. @persist and @blank already exist in disko.nix.
  # dotnix.persistence.enable = true;

  nixpkgs.config.allowUnfree = true;
  nix.settings.allowed-users = [ "aenri" ];
  nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 30d"; };
  nix.optimise.automatic = true;
  
  
  # Without this NixOS defaults to grub and the build fails an assertion --
  # and even if it didn't, the EVO would have no bootloader.
  #
  # systemd-boot for the first install. Switching to lanzaboote is a second
  # step, after `sbctl create-keys` on the running system:
  #   boot.loader.systemd-boot.enable = lib.mkForce false;
  #   boot.lanzaboote = { enable = true; pkiBundle = "/var/lib/sbctl"; };
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  programs.zsh.enable = true;

  networking.hostName = "deaddove";
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
      ./deaddove/desktop.nix
    ];
  };

  dotnix.greeter = {
    enable = true;
    sync-users = [ "aenri" ];
    settings = {
      session.default = "niri";
      keyboard.layout = "us";
      cursor = { theme = "capitaine-cursors"; size = 24; };
    };
  };
  
  services.udisks2.enable = true;
  hardware.bluetooth.enable = true;

  networking.networkmanager.enable = true;

  environment.variables.EDITOR = "nvim";
  programs.neovim = { enable = true; defaultEditor = true; };
  security.rtkit.enable = true;


  environment.systemPackages = with pkgs; [
      git wget jq
      file tree unzip zip
      ripgrep fd
      htop lsof psmisc
      pciutils usbutils dmidecode smartmontools ethtool
      tmux capitaine-cursors
    ];
}
