{ lib, ... }:
{
  imports = [
    ./zen-browser
    ./zed.nix
    ./alacritty.nix
  ];
  dotnix.home.gui = lib.mkDefault true;
}