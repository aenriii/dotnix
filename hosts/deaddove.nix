{ pkgs, inputs, ... }:
{
  imports = [
    ../modules
    ./deaddove/disko.nix
    ./deaddove/hardware.nix
    ./deaddove/services/vaultwarden.nix
    ./deaddove/services/kiri.nix
    ./deaddove/virtualization.nix
  ];
  networking.hostName = "deaddove";
  time.timeZone = "America/Indiana/Indianapolis";
  system.stateVersion = "26.05";
  nixpkgs.config.allowUnfree = true;
  security.rtkit.enable = true;

  xdg.portal = {
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.niri.default = [
      "gtk"
      "gnome"
    ];
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
  hardware = {
    enableRedistributableFirmware = true;
    graphics.enable32Bit = true;
  };
  nix = {
    settings.allowed-users = [ "aenri" "kiri" "nixremote" ];
    gc = { 
      automatic = true; 
      dates = "weekly"; 
      options = "--delete-older-than 30d"; 
    };
    optimise.automatic = true;
  };
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    extraModprobeConfig = ''
      options kvm ignore_msrs=1 report_ignored_msrs=0
      options hid_apple fnmode=2
    '';
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
  users.users = {
    aenri = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "video" "audio" "libvirtd" ];
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGfuU89xnxyVwg3nf/+1q8qqkEljPEfJYYa6jZcffnez aenri@deaddove"
      ];
    };
    nixremote = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOO57k/E9X6EF/FYdVwR5sP4sIaOSt/Jp9guoxGHXgHb root@villa"
      ];
    };
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
      ../users/aenri/configs/school
      ./deaddove/desktop.nix
    ];

    users.kiri.imports = [ ../users/kiri.nix ];
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
    iloader.enable = true;
  };
  services = {
    udisks2.enable = true;
    pcscd.enable = true;
    openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };
  environment = {
    variables.EDITOR = "nvim";
    systemPackages = with pkgs; [
        git wget jq
        file tree unzip zip
        ripgrep fd
        htop lsof psmisc
        pciutils usbutils dmidecode smartmontools ethtool
        tmux capitaine-cursors
      ];
  };
}
