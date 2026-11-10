{ pkgs, ... }:
{
  imports = [
    ./theming.nix
    ./niri
    ./noctalia-shell
  ];
  home.pointerCursor = {
    enable  = true;
    package = pkgs.capitaine-cursors;
    name    = "capitaine-cursors";
    size    = 24;
    gtk.enable = true;
  };
  dotnix.home.sandbox = {
    signal-desktop = {
      allocator = "libc";
      package = pkgs.symlinkJoin {
        name = "signal-desktop";
        paths = [ pkgs.signal-desktop ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/signal-desktop \
            --add-flags "--password-store=gnome-libsecret"
        '';
        inherit (pkgs.signal-desktop) meta;
      };
    };
    equibop.allocator = "libc";
    obsidian.allocator = "libc";
    whatsapp-electron.allocator = "libc";
    telegram-desktop.allocator = "libc";
    google-chrome.allocator = "libc";
    cider-2.allocator = "libc";
    claude-desktop.allocator = "libc";
    zoom-us.allocator = "libc";
  };
  home.packages = with pkgs; [
    vlc
    qbittorrent
    obs-studio
    nautilus
    keyroost
    fractal
  ];

}