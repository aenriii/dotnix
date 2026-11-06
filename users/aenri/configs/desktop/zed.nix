{ lib, pkgs, ... }:
{
  programs.zed-editor = {
    enable = true;
    package = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin null;
    extensions = [ "rs" "toml" "nix" "make" "md" "svelte" "ts" "js" "json" ];
    userSettings = {
      lsp = {
        rust-analyzer = {
          binary = {
            path_lookup = true;
          };
        };
        nix = {
          binary = {
            path_lookup = true;
          };
        };
      };
      theme = {
        mode = "system";
        light = "Catppuccin Latte";
        dark = "Catppuccin Mocha";
      };
      load_direnv = "shell_hook";
    };
  };
}