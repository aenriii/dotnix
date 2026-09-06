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
  dotnix.home.sandbox.zen-browser = {
    allocator = "libc";
    package = zen;
  };
}
