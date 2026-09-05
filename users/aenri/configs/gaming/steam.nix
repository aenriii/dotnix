{ pkgs, ... }:
let
  steam = pkgs.steam.override {
    extraPkgs = pkgs': with pkgs'; [
      libXcursor
      libXi
      libXinerama
      libXScrnSaver
      libpng
      libpulseaudio
      libvorbis
      stdenv.cc.cc.lib
      libkrb5
      keyutils
      gamescope
    ];
    extraEnv = { QT_QPA_PLATFORM = "xcb"; };
  };
in
{
  home.packages = [ steam ];
}