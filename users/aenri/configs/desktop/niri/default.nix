{ config, lib, pkgs, scripts, ... }:
  # `call` hand-rolls the module args for the files below, so anything they
  # need must be listed here -- they are plain imports, not modules.
  let call = lib.flip import {
    inherit lib pkgs scripts config;
  };
in
{
  # NOTE: do NOT import inputs.niri-flake.homeModules.config here.
  # niri-flake's nixosModules.niri already appends it to
  # home-manager.sharedModules whenever home-manager is present, and importing
  # it twice is a duplicate declaration of programs.niri.finalConfig.
  #
  # The consequence is that this module only works with home-manager running
  # as a NixOS module. A standalone homeConfiguration that wants niri has to
  # add homeModules.config at the composition root instead.

  # No `enable` here: niri-flake's homeModules.config declares only
  # `programs.niri.package` and `.settings`. Installing niri and setting up
  # the session is a NixOS-level concern -- see programs.niri.enable in
  # hosts/deaddove.nix.

  home.packages = [ pkgs.xwayland-satellite ];

  programs.niri = {
    settings = {
      binds = call ./keybinds.nix;
      animations = call ./animations.nix;
      spawn-at-startup = [
        { command = [ "xwayland-satellite" ":0" ]; }
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