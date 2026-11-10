{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.dotnix.claude-display;

  # get rid of graphene hardened malloc for chromium
  libcMallocLaunch = pkgs.writeShellScript "libc-malloc-launch" ''
    target="$1"
    shift
    if preload="$(${pkgs.coreutils}/bin/readlink -f /etc/ld-nix.so.preload 2>/dev/null)" \
       && [ -f "$preload" ]; then
      exec ${pkgs.bubblewrap}/bin/bwrap \
        --dev-bind / / \
        --ro-bind ${pkgs.emptyFile} $preload \
        --die-with-parent \
        -- "$target" "$@"
    fi

    exec "$target" "$@"
  '';

  browserExe = lib.getExe cfg.browser;
in
{
  # Imported here so enabling this one module is enough (cf. persistence.nix).
  imports = [ inputs.claude-desktop.nixosModules.default ];

  options.dotnix.claude-display = {
    enable = lib.mkEnableOption "a headless sway display for Claude (Computer Use + Claude in Chrome)";

    user = lib.mkOption {
      type = lib.types.str;
      description = "Account the display runs for.";
    };

    browser = lib.mkOption {
      type = lib.types.package;
      default = pkgs.chromium;
      defaultText = lib.literalExpression "pkgs.chromium";
      description = "Chromium-family browser started on the display.";
    };

    allocator = lib.mkOption {
      type = lib.types.enum [
        "inherit"
        "libc"
      ];
      default = "libc";
      description = ''
        'libc' starts the browser outside the system-wide hardened malloc
        (Chromium aborts under it); 'inherit' leaves it as is.
      '';
    };


    autostart = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = "Extra commands started once on the display.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The fork's seat-based (uaccess) rules: TPM for Claude Desktop's device
    # key, KVM + vhost_vsock for the local Cowork VM.
    programs.claude-desktop-extra.tpmAccess.enable = lib.mkDefault true;
    programs.claude-desktop-extra.kvmAccess.enable = lib.mkDefault true;

    programs.claude-desktop-extra.backgroundDisplay = {
      enable = true;
      inherit (cfg) user autostart;
      browser = {
        package = cfg.browser;
        executable = if cfg.allocator == "libc" then "${libcMallocLaunch} ${browserExe}" else browserExe;
      };
    };
  };
}
