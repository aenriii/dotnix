# A nixos container that is its own tailnet node and publishes one local
# port over https with `tailscale serve`.
#
#   imports = [ (import ./tailnet-container.nix { name = "foo"; ... }) ];
#
# The container is reachable at https://<hostName>.gentoo-danio.ts.net.
#
# secrets/tailscale-authkey is an oauth client secret scoped to tag:service,
# so it never expires. Containers join as tag:service (anyone on the tailnet)
# or tag:service-private (aenri only); the tailnet policy file is what
# actually enforces that.
{
  name,
  hostName ? name,
  shared ? false,
  stateVersion ? "26.05",
  # container gets 10.233.<subnet>.2, host side 10.233.<subnet>.1
  subnet,
  port,
  bindMounts ? { },
  forwardPorts ? [ ],
  container,
}:
{ config, ... }:
let
  secret = "${name}-tailscale-authkey";
  tag = if shared then "tag:service" else "tag:service-private";
  tailscaleState = "/persist/${name}/tailscale-state";
in
{
  sops.secrets.${secret} = {
    sopsFile = ./secrets/tailscale-authkey;
    format = "binary";
  };

  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-${name}" ];
  };

  systemd.tmpfiles.rules = [
    "d ${tailscaleState} 0700 root root -"
  ];

  containers.${name} = {
    autoStart = true;
    ephemeral = true;

    privateNetwork = true;
    hostAddress = "10.233.${toString subnet}.1";
    localAddress = "10.233.${toString subnet}.2";
    enableTun = true;
    inherit forwardPorts;
    # the host only brings up our veth once nspawn reports ready, and by
    # default that waits for the container's whole boot transaction,
    # tailscaled-autoconnect included; a first-time login needs the network,
    # so it deadlocks. lands after the module's --notify-ready=yes, so wins.
    extraFlags = [ "--notify-ready=no" ];

    bindMounts = bindMounts // {
      "/var/lib/tailscale" = {
        hostPath = tailscaleState;
        isReadOnly = false;
      };
      "/run/secrets/tailscale-authkey" = {
        hostPath = config.sops.secrets.${secret}.path;
        isReadOnly = true;
      };
    };

    config =
      { pkgs, ... }:
      {
        imports = [ container ];

        system.stateVersion = stateVersion;

        networking.firewall.enable = true;

        networking.hostName = hostName;

        networking.nameservers = [
          "1.1.1.1"
          "9.9.9.9"
        ];

        services.tailscale = {
          enable = true;
          authKeyFile = "/run/secrets/tailscale-authkey";
          authKeyParameters = {
            ephemeral = false;
            preauthorized = true;
          };
          # only applies on first join; re-tag existing nodes in the admin console
          extraUpFlags = [
            "--accept-dns=false"
            "--advertise-tags=${tag}"
          ];
        };

        systemd.services.tailscaled-autoconnect.serviceConfig = {
          TimeoutStartSec = "15s";
          Restart = "on-failure";
          RestartSec = "5s";
        };

        systemd.services.tailscale-serve = {
          description = "Publish ${name} via tailscale serve";
          after = [ "tailscaled-autoconnect.service" ];
          wants = [ "tailscaled-autoconnect.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            Restart = "on-failure";
            RestartSec = "5s";
            ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg ${toString port}";
            ExecStop = "${pkgs.tailscale}/bin/tailscale serve reset";
          };
        };
      };
  };
}
