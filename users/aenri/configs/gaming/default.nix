{ pkgs, lib, ... }:
{
  imports = [
    ./steam.nix
  ];

  home.packages = with pkgs; [
    prismlauncher
  ];
  
  dotnix.home.gaming = lib.mkDefault true;
}