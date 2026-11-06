{ pkgs, lib, ... }:
{
  gtk = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    enable = true;
    font = {
      name = "Fira Sans";
      size = 10;
    };
    cursorTheme = {
      name = "capitaine-cursors";
      package = pkgs.capitaine-cursors;
      size = 24;
    };
    colorScheme = "dark";
  };
  home.packages = lib.mkIf pkgs.stdenv.hostPlatform.isLinux [ pkgs.nordic ];
}
