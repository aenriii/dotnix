{ pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  users.users.kiri = {
    isNormalUser = true;
    home = "/home/kiri";
    createHome = true;
    shell = pkgs.zsh;
    description = "Kiri";
  };

  # Safety net for whatever's left in her home dir that isn't declared in
  # users/kiri.nix (random prebuilt binaries in personal projects, etc.) --
  # lets dynamically-linked ELF binaries not packaged by nix run unmodified.
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    python3
    gnupg
    curl
  ];

  systemd.tmpfiles.rules = [
    "L+ /home/kiri/.local/bin/claude - - - - ${inputs.claude-code.packages.${system}.claude-code}/bin/claude"
  ];


  systemd.services.kiri-gateway = {
    description = "Kiri Telegram Gateway";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = "kiri";
      WorkingDirectory = "/home/kiri/glue";
      ExecStart = "${pkgs.python3}/bin/python3 /home/kiri/glue/kiri-gateway.py";
      Restart = "on-failure";
      RestartSec = 10;
      Environment = "PATH=/etc/profiles/per-user/kiri/bin:/run/current-system/sw/bin:/usr/bin:/bin";
      EnvironmentFile = "/home/kiri/.env";
      StandardOutput = "append:/home/kiri/logs/gateway-stdout.log";
      StandardError = "append:/home/kiri/logs/gateway-stderr.log";
    };
  };

  systemd.services.kiri-heartbeat = {
    description = "Kiri Heartbeat — Autonomous Time";
    serviceConfig = {
      Type = "oneshot";
      User = "kiri";
      ExecStart = "/home/kiri/glue/heartbeat.sh";
      Environment = "PATH=/etc/profiles/per-user/kiri/bin:/run/current-system/sw/bin:/usr/bin:/bin";
      EnvironmentFile = "/home/kiri/.env";
      StandardOutput = "append:/home/kiri/logs/heartbeat-stdout.log";
      StandardError = "append:/home/kiri/logs/heartbeat-stderr.log";
    };
  };

  systemd.timers = {
    kiri-heartbeat-morning = {
      description = "Kiri Heartbeat / Morning (9:00)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 09:00:00";
        Persistent = true;
        Unit = "kiri-heartbeat.service";
      };
    };
    kiri-heartbeat-afternoon = {
      description = "Kiri Heartbeat / Afternoon (14:00)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 14:00:00";
        Persistent = true;
        Unit = "kiri-heartbeat.service";
      };
    };
    kiri-heartbeat-evening = {
      description = "Kiri Heartbeat / Evening (20:00)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 20:00:00";
        Persistent = true;
        Unit = "kiri-heartbeat.service";
      };
    };
  };
}
