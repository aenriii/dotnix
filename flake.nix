{

  description = "hi!";
  
  inputs = {

    # system-wide configuration
    
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
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


    # out-of-nixpkgs apps
    
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
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

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
  };
  outputs = inputs @ { 
    self, 
    # system configuration
    nixpkgs, pyria, home-manager,
    lanzaboote, disko, sops-nix,
    impermanence,
    # out-of-nixpkgs apps
    zen-browser, nixgl, niri-flake,
    noctalia-shell, noctalia-greeter,
    claude-code, deploy-rs,
  }: {
    nixosConfigurations.deaddove = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit self inputs; };

      modules = [
        disko.nixosModules.disko
        lanzaboote.nixosModules.lanzaboote
        home-manager.nixosModules.home-manager
        sops-nix.nixosModules.sops
        niri-flake.nixosModules.niri
        pyria.nixosModules.pyria
        ./hosts/deaddove.nix
      ];
    };
    nixosConfigurations.villa = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit self inputs; };

      modules = [
        disko.nixosModules.disko
        lanzaboote.nixosModules.lanzaboote
        impermanence.nixosModules.impermanence
        home-manager.nixosModules.home-manager
        sops-nix.nixosModules.sops
        niri-flake.nixosModules.niri
        pyria.nixosModules.pyria
        ./hosts/villa.nix
      ];
    };

    homeConfigurations.aenri = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = { inherit self inputs; };
      modules = [
        ./users/aenri.nix
      ];
    };
    homeConfigurations."aenri@gui" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = { inherit self inputs; };
      modules = [
        ./users/aenri.nix
        ./users/aenri/configs/desktop
      ];
    };
  };
  
}