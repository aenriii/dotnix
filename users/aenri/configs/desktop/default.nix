{ pkgs, lib, inputs, ... }:
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
    google-chrome.allocator = "libc";
    cider-2.allocator = "libc";
    claude-desktop.allocator = "libc";
  };
  home.packages = with pkgs; [
    vlc
    qbittorrent
    obs-studio
    nautilus
    keyroost
  ];
  dotnix.home.gui = lib.mkDefault true;
}