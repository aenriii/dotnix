{ lib, config, ... }:
let
  cfg = config.dotnix.tpm;
in
{
  options.dotnix.tpm = {
    enable = lib.mkEnableOption "owner/group access to the TPM device nodes";

    owner = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Owner of /dev/tpm* and /dev/tpmrm*.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "users";
      description = ''
        Group of the TPM nodes. Any member can use the TPM, including clearing
        it or tripping its lockout when the owner/lockout auth is empty: set
        those first (tpm2_changeauth -c owner, -c lockout).
      '';
    };

    mode = lib.mkOption {
      type = lib.types.strMatching "0[0-7]{3}";
      default = "0660";
      description = ''
        Mode of /dev/tpmrm* (the kernel resource manager; any number of openers).
      '';
    };

    rawMode = lib.mkOption {
      type = lib.types.strMatching "0[0-7]{3}";
      default = "0660";
      description = ''
        Mode of the raw /dev/tpm*. It has a single opener at a time, whatever
        the open mode, and read-only access cannot send commands: an o+r here
        only lets any account hold the device busy.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.udev.extraRules = ''
      SUBSYSTEM=="tpmrm", KERNEL=="tpmrm[0-9]*", OWNER="${cfg.owner}", GROUP="${cfg.group}", MODE="${cfg.mode}"
      SUBSYSTEM=="tpm", KERNEL=="tpm[0-9]*", OWNER="${cfg.owner}", GROUP="${cfg.group}", MODE="${cfg.rawMode}"
    '';
  };
}
