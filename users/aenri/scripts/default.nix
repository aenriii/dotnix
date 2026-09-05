{ pkgs, ... }:
{
  # Defined unconditionally on purpose. `_module.args` values are not option
  # definitions, so a `lib.mkIf` here is never discharged -- it survives as a
  # literal { _type = "if"; ... } attrset and breaks `lib.getExe scripts.*`
  # in niri/keybinds.nix. Building a small script on a headless host is
  # cheaper than the failure mode.
  _module.args.scripts = {
    screenshot = import ./screenshot.nix { inherit pkgs; };
  };
}
