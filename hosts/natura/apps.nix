{ config, ... }:
{
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    casks = [
      "signal" "obsidian" "telegram"
      "google-chrome" "claude" "zoom"
      "vlc" "qbittorrent" "obs" "zed"
      "alacritty"
    ];
    masApps.WhatsApp = 310633997;
    taps = builtins.attrNames config.nix-homebrew.taps;
  };
}