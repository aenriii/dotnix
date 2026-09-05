{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.home.sandbox;

  libcMallocLaunch = pkgs.writeShellScript "libc-malloc-launch" ''
    target="$1"
    shift

    if [ -e /etc/ld-nix.so.preload ]; then
      exec ${pkgs.bubblewrap}/bin/bwrap \
        --dev-bind / / \
        --ro-bind ${pkgs.emptyFile} /etc/ld-nix.so.preload \
        --die-with-parent \
        -- "$target" "$@"
    fi

    exec "$target" "$@"
  '';

  wrapLibcMalloc =
    name: pkg:
    pkgs.runCommand "${name}-libc-malloc"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        meta = pkg.meta or { };
        passthru = (pkg.passthru or { }) // {
          unwrapped = pkg;
        };
      }
      ''
        mkdir -p "$out/bin"

        # Farm the package, holding back the two trees we rewrite.
        for d in ${pkg}/*; do
          [ -e "$d" ] || continue
          case "$(basename "$d")" in
            bin|share) ;;
            *) ln -s "$d" "$out/$(basename "$d")" ;;
          esac
        done

        if [ -d ${pkg}/share ]; then
          mkdir -p "$out/share"
          for d in ${pkg}/share/*; do
            [ -e "$d" ] || continue
            case "$(basename "$d")" in
              applications) ;;
              *) ln -s "$d" "$out/share/$(basename "$d")" ;;
            esac
          done
        fi

        for f in ${pkg}/bin/*; do
          [ -e "$f" ] || continue
          makeWrapper ${libcMallocLaunch} "$out/bin/$(basename "$f")" \
            --add-flags "$f"
        done

        # .desktop files bake in an absolute ''${pkg}/bin/... path, so anything
        # started from an app launcher bypasses the wrapper and silently keeps
        # the hardened allocator. Materialize them and repoint at $out/bin.
        # (Entries using a bare `Exec=foo` resolve through PATH and already
        # hit the wrapper, so the sed simply finds nothing to do.)
        if [ -d ${pkg}/share/applications ]; then
          mkdir -p "$out/share/applications"
          cp -rL ${pkg}/share/applications/. "$out/share/applications/"
          chmod -R u+w "$out/share/applications"
          find "$out/share/applications" -type f \
            -exec sed -i "s|${pkg}/bin/|$out/bin/|g" {} +
        fi
      '';

  # ---- policy -> package ----------------------------------------------

  resolve = name: policy: if policy.package != null then policy.package else pkgs.${name};

  applyPolicy =
    name: policy:
    let
      pkg = resolve name policy;
    in
    if policy.allocator == "libc" then wrapLibcMalloc name pkg else pkg;
in
{
  options.dotnix.home.sandbox = lib.mkOption {
    default = { };
    example = lib.literalExpression ''
      {
        google-chrome.allocator = "libc";
        gamescope = {
          allocator = "libc";
          package = myGamescope;
        };
      }
    '';
    description = ''
      Applications installed with an explicit sandbox policy.

      This both declares the policy and installs the package.

      The attribute name is looked up in pkgs unless `package` is set.
    '';
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          allocator = lib.mkOption {
            type = lib.types.enum [
              "inherit"
              "libc"
            ];
            default = "inherit";
            description = ''
              Which memory allocator the application runs under.

              'inherit' takes the system-wide setting
              (environment.memoryAllocator.provider).

              'libc' opts out, for applications that break under
              graphene-hardened-malloc.
            '';
          };

          package = lib.mkOption {
            type = lib.types.nullOr lib.types.package;
            default = null;
            defaultText = lib.literalExpression "pkgs.\${name}";
            description = ''
              Package to install. Defaults to the attribute name looked up in
              pkgs; set explicitly when the name doesn't match or the package
              needs an override applied first.
            '';
          };
        };
      }
    );
  };

  config = {
    assertions = lib.mapAttrsToList (name: policy: {
      assertion = policy.package != null || pkgs ? ${name};
      message = ''
        dotnix.home.sandbox.${name}: no `pkgs.${name}`. Set `package` explicitly.
      '';
    }) cfg;

    home.packages = lib.mapAttrsToList applyPolicy cfg;
  };
}
