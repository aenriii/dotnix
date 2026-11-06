{ inputs, pkgs, lib, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  zen-browser = inputs.zen-browser.packages.${system}.zen-browser-unwrapped;
  prefs = import ./prefs.nix;
  zen = pkgs.wrapFirefox zen-browser {
    extraPrefs = lib.concatLines (
        lib.mapAttrsToList (name: value: ''lockPref(${lib.strings.toJSON name}, ${lib.strings.toJSON value});''
  	) prefs );
    extraPolicies = { ExtensionSettings = import ./extensions.nix; } // import ./policies.nix;
  };
in
{
  imports = [ ./darwin.nix ];

  # linux: everything is baked into the wrapped browser. macOS can't do that
  # without unsigning Zen.app, see darwin.nix.
  dotnix.home.sandbox = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    zen-browser = {
      allocator = "libc";
      package = zen;
    };
  };
}
