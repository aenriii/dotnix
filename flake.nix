{

  description = "hi!";

  inputs = {

    # system-wide configuration

    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyria = {
      url = "github:lvehrt/pyria.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    NixVirt =
      {
        url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
        inputs.nixpkgs.follows = "nixpkgs";
      };

    # out-of-nixpkgs apps

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # macOS-only: youwen5's flake has no darwin build. this one ships the
    # upstream-signed .app plus a home-manager module that delivers policies
    # through `defaults` instead of writing into (and unsigning) the bundle.
    zen-browser-darwin = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia-shell = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop = {
      url = "github:patrickjaja/claude-desktop-extra";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    iloader = {
      url = "github:nab138/iloader";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    keyroost = {
      url = "github:framefilter/keyroost";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };

    # cask inputs

    homebrew-core = { url = "github:homebrew/homebrew-core"; flake = false; };
    homebrew-cask = { url = "github:homebrew/homebrew-cask"; flake = false; };
  };
  outputs = inputs @ {
    self,
    # system configuration
    nixpkgs, nix-darwin, pyria, home-manager,
    lanzaboote, disko, sops-nix, impermanence,
    NixVirt,
    # out-of-nixpkgs apps
    zen-browser, zen-browser-darwin, nixgl,
    niri-flake, noctalia-shell, noctalia-greeter,
    claude-code, claude-desktop, deploy-rs,
    iloader, keyroost, nix-homebrew
    # cask inputs

  }:
  let
    # my awesome overlay
    my-awesome-overlay = final: prev: {
      claude-code = claude-code.packages.${final.stdenv.hostPlatform.system}.claude-code;
      claude-desktop = claude-desktop.packages.${final.stdenv.hostPlatform.system}.default;
      keyroost = keyroost.packages.${final.stdenv.hostPlatform.system}.keyroost;
      librepods = final.callPackage ./pkgs/librepods { };
    };
  in {
    nixosConfigurations.deaddove = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit self inputs; };

      modules = [
        { nixpkgs.overlays = [ my-awesome-overlay ]; }
        disko.nixosModules.disko
        lanzaboote.nixosModules.lanzaboote
        home-manager.nixosModules.home-manager
        sops-nix.nixosModules.sops
        niri-flake.nixosModules.niri
        pyria.nixosModules.pyria
        ./hosts/deaddove.nix
      ];
    };
#     nixosConfigurations.villa = nixpkgs.lib.nixosSystem {
#       system = "x86_64-linux";
#       specialArgs = { inherit self inputs; };
# 
#       modules = [
#         { nixpkgs.overlays = [ my-awesome-overlay ]; }
#         disko.nixosModules.disko
#         lanzaboote.nixosModules.lanzaboote
#         home-manager.nixosModules.home-manager
#         sops-nix.nixosModules.sops
#         niri-flake.nixosModules.niri
#         pyria.nixosModules.pyria
#         ./hosts/villa.nix
#       ];
#     };
    darwinConfigurations.natura = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = { inherit self inputs; };
      modules = [
        { nixpkgs.overlays = [ my-awesome-overlay ]; }
        nix-homebrew.darwinModules.nix-homebrew
        home-manager.darwinModules.home-manager
        ./hosts/natura.nix
      ];
    };

    homeConfigurations.aenri = home-manager.lib.homeManagerConfiguration {
      extraSpecialArgs = { inherit self inputs; };
      modules = [
        { nixpkgs.overlays = [ my-awesome-overlay ]; }
        ./users/aenri.nix
      ];
    };
    homeConfigurations."aenri@gui" = home-manager.lib.homeManagerConfiguration {
      extraSpecialArgs = { inherit self inputs; };
      modules = [
        { nixpkgs.overlays = [ my-awesome-overlay ]; }
        ./users/aenri.nix
        ./users/aenri/configs/desktop
      ];
    };
  };

}
