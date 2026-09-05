{
  lib,
  config,
  pkgs,
  utils,
  inputs,
  ...
}:
let
  cfg = config.dotnix.persistence;
  root = "/persist";

  rootDevice = config.fileSystems."/".device;
  rootDeviceUnit = "${utils.escapeSystemdPath rootDevice}.device";

  extraRoots = lib.subtractLists [ root ] (builtins.attrNames config.environment.persistence);
in
{
  # Imported here rather than in flake.nix so a host gets impermanence by
  # importing this one file, and can't end up with dotnix.persistence.enable
  # set but no impermanence module in scope.
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  options.dotnix.persistence = {
    enable = lib.mkEnableOption "impermanence";

    wipe = lib.mkOption {
      type = lib.types.enum [
        "none"
        "btrfs-rollback"
      ];
      default = "none";
      description = ''
        What to do with / on boot.

        'none' leaves / alone. Persistence still applies, so this is the
        mode to run in while you find out what you forgot to persist.

        'btrfs-rollback' deletes the @ subvolume in initrd and recreates it
        from @blank. Requires systemd initrd and an empty @blank subvolume
        alongside @.
      '';
    };

    directories = lib.mkOption {
      type = with lib.types; listOf (either str attrs);
      default = [ ];
      example = [ "/var/lib/tailscale" ];
      description = ''
        Directories to persist across a wipe.

        Everything goes through here rather than straight to
        environment.persistence so ${root} is spelled exactly once. A typo'd
        root is otherwise a valid attribute name and fails silently.

        Entries may be plain paths or impermanence attrsets:
          { directory = "/var/lib/foo"; user = "foo"; mode = "0700"; }

        Feature modules should append their own state here next to whatever
        needs it, e.g. modules/network/tailscale.nix owning
        /var/lib/tailscale. Definitions are harmless on hosts where
        persistence is disabled.
      '';
    };

    files = lib.mkOption {
      type = with lib.types; listOf (either str attrs);
      default = [ ];
      example = [ "/etc/machine-id" ];
      description = "Individual files to persist. See `directories`.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = extraRoots == [ ];
        message = ''
          Unexpected persistence root(s): ${lib.concatStringsSep ", " extraRoots}

          Something defined environment.persistence directly instead of going
          through dotnix.persistence.{directories,files}. environment.persistence
          is an attrsOf, so a misspelled root is a valid attribute name and
          would silently persist nothing.
        '';
      }
      {
        assertion = cfg.wipe == "btrfs-rollback" -> config.boot.initrd.systemd.enable;
        message = ''
          dotnix.persistence.wipe = "btrfs-rollback" needs boot.initrd.systemd.enable.
          The rollback runs as an initrd systemd unit; the scripted initrd would
          need boot.initrd.postDeviceCommands instead, which systemd initrd ignores.
        '';
      }
      {
        assertion = cfg.wipe == "btrfs-rollback" -> rootDevice != null;
        message = "dotnix.persistence: can't roll back / -- fileSystems.\"/\".device is unset.";
      }
    ];

    dotnix.persistence = {
      directories = [
        # uid/gid allocations. Without this users are renumbered on every
        # boot and file ownership drifts out from under you.
        "/var/lib/nixos"
        "/var/log"
      ];
      files = [
        "/etc/machine-id"
        # sops-nix derives its age key from the host key by default, so
        # losing this means secrets stop decrypting -- including the
        # password file, if you moved to hashedPasswordFile.
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
      ];
    };

    environment.persistence.${root} = {
      hideMounts = true;
      inherit (cfg) directories files;
    };

    # Merges onto the entry disko generates for @persist.
    fileSystems.${root}.neededForBoot = true;

    boot.initrd.systemd = lib.mkIf (cfg.wipe == "btrfs-rollback") {
      storePaths = [ "${pkgs.btrfs-progs}/bin/btrfs" ];

      services.rollback = {
        description = "Roll back / to a blank btrfs subvolume";
        wantedBy = [ "initrd.target" ];
        requires = [ rootDeviceUnit ];
        after = [ rootDeviceUnit ];
        before = [ "sysroot.mount" ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        script = ''
          btrfs=${pkgs.btrfs-progs}/bin/btrfs

          mkdir -p /rollback
          mount -o subvol=/ ${rootDevice} /rollback

          # Nested subvolumes (docker, nspawn, ...) block deleting @.
          $btrfs subvolume list -o /rollback/@ \
            | cut -f9 -d' ' \
            | while read -r sub; do
                $btrfs subvolume delete "/rollback/$sub"
              done

          $btrfs subvolume delete /rollback/@
          $btrfs subvolume snapshot /rollback/@blank /rollback/@

          umount /rollback
        '';
      };
    };
  };
}
