{ pkgs, lib, ... }:
{
  imports = [
    ./niri
    ./noctalia-shell
    ./zen-browser
    ./zed.nix
    ./alacritty.nix
    ./theming.nix
  ];

  dotnix.home.sandbox = {
    signal-desktop.allocator = "libc";
    equibop.allocator = "libc";
    obsidian.allocator = "libc";
    whatsapp-electron.allocator = "libc";
    telegram-desktop.allocator = "libc";
  };
  home.packages = with pkgs; [
    vlc
    qbittorrent
    obs-studio
    nautilus
    cider-2
  ];
  dotnix.home.gui = lib.mkDefault true;
}