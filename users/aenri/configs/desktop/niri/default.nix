{ config, lib, pkgs, scripts, ... }:
  # `call` hand-rolls the module args for the files below, so anything they
  # need must be listed here -- they are plain imports, not modules.
  let
    call = lib.flip import {
      inherit lib pkgs scripts config;
    };
    # hello https://github.com/Supreeeme/xwayland-satellite/issues/468
    xwayland-satellite = pkgs.xwayland-satellite.overrideAttrs (
      old:
      let
        version = "0.8.1";
        src = pkgs.fetchFromGitHub {
          owner = "Supreeeme";
          repo = "xwayland-satellite";
          tag = "v${version}";
          hash = "sha256-BUE41HjLIGPjq3U8VXPjf8asH8GaMI7FYdgrIHKFMXA=";
        };
      in
      {
        inherit version src;
        # buildRustPackage closes over the *original* `cargoHash` argument
        # when deriving `cargoDeps`, so overriding `cargoHash` here is a
        # no-op -- `cargoDeps` itself has to be overridden directly.
        cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
          inherit (old) pname;
          inherit version src;
          hash = "sha256-16L6gsvze+m7XCJlOA1lsPNELE3D364ef2FTdkh0rVY=";
        };
      }
    );
  in
{

  home.packages = [ xwayland-satellite ];

  programs.niri = {
    settings = {
      binds = call ./keybinds.nix;
      animations = call ./animations.nix;
      spawn-at-startup = [
        { command = [ "${lib.getExe xwayland-satellite}" ":0" ]; }
      ];
      # `outputs` is deliberately absent: connectors are host-specific and
      # come from hosts/<host>/desktop.nix. Note these `call`ed values bypass
      # the module system, so anything defined here CANNOT be overridden by a
      # host -- only merged into. Move a setting out of `call` if a host ever
      # needs to change it.
      input = call ./input.nix;
      layout = call ./layout.nix;
      window-rules = call ./rules.nix;
      environment = {
        QT_QPA_PLATFORM = "wayland";
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
        QT_QPA_PLATFORMTHEME = "gtk3";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        XDG_CURRENT_DESKTOP = "niri";
        XDG_SESSION_TYPE = "wayland";
        DISPLAY = ":0";
      };
      prefer-no-csd = true;
      screenshot-path = null;
      cursor = {
        theme = "capitaine-cursors";
        size = 24;
      };
      debug = {
        honor-xdg-activation-with-invalid-serial = [ ];
      };
      hotkey-overlay.skip-at-startup = true;
      # blur = {
      #   passes = 1;
      #   offset = 2.0;
      # };
    };
  };
}