{ pkgs, lib, ... }:
{
  imports = [
    ./niri
    ./noctalia-shell
    ./zen-browser
    ./zed.nix
  ];

  dotnix.home.sandbox = {
    signal-desktop.allocator = "libc";
    equibop.allocator = "libc";
    obsidian.allocator = "libc";
    whatsapp-electron.allocator = "libc";
  };
  home.packages = with pkgs; [
    vlc
    qbittorrent
    obs-studio
  ];
  dotnix.home.gui = lib.mkDefault true;
}