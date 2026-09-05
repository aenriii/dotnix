{ pkgs, ... }:
{
  imports = [
    ./zsh
    ./dev.nix
  ];
  home.packages = with pkgs; [
    tailscale
    openjdk25
  ];
}