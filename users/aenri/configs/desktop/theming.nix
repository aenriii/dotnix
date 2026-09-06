{ pkgs, ... }:
{
  gtk = {
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

    theme = {
      name = "adw-gtk3";
      package = pkgs.adw-gtk3;
    };
    gtk3.extraConfig = {
      gtk-button-images = true;
      gtk-menu-images = true;
      gtk-modules = "colorreload-gtk-module:appmenu-gtk-module";
      gtk-primary-button-warps-slider = false;
    };
    gtk3.bookmarks = [
      "file:///home/aenri/Documents"
      "file:///home/aenri/Pictures"
      "file:///home/aenri/Videos"
      "file:///home/aenri/Downloads"
    ];

    gtk4.theme = {
      name = "Nordic-darker";
      package = pkgs.nordic;
    };
    gtk4.extraConfig = {
      gtk-button-images = true;
      gtk-menu-images = true;
      gtk-modules = "colorreload-gtk-module:appmenu-gtk-module";
      gtk-primary-button-warps-slider = false;
      gtk-shell-shows-menubar = 1;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };
  qt.kvantum = {
    enable = true;
    settings.General.theme = "Nordic-Darker-Solid";
  };
  home.packages = [ pkgs.nordic ];
}
