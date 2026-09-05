{
  lib,
  pkgs,
  inputs,
  config,
  options,
  ...
}:
let
  cfg = config.dotnix.greeter;
  # `settings` below references this; without it the option declaration itself
  # throws "undefined variable", even with the greeter disabled.
  tomlFormat = pkgs.formats.toml { };
in

{
  imports = [ inputs.noctalia-greeter.nixosModules.default ];
  options.dotnix.greeter = {
    enable = lib.mkEnableOption "noctalia-greeter";
    sync-users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "aenri" ];
      description = "Passthrough for passwordless-sync-users";
    };
    settings = lib.mkOption {
      type = with lib.types; oneOf [tomlFormat.type str path];
      default = {};
      description = "Passthrough for noctalia-greeter.settings";
    };
  };
  config = lib.mkIf cfg.enable {
    programs.noctalia-greeter = {
      enable = true;
      passwordless-sync-users = cfg.sync-users;
      settings = cfg.settings;
    };
  };
}