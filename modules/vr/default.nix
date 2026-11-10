{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.vr;
in
{
  options.dotnix.vr = {
    enable = lib.mkEnableOption "SteamVR support (steam itself still comes from home-manager)";

    alvr = {
      enable = lib.mkEnableOption "ALVR, streaming SteamVR to a standalone headset over wifi";

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Open 9943-9944 tcp+udp. 9943 is also where the headset broadcasts
          to find the streamer, so without it the dashboard never sees it.
        '';
      };

      wired = lib.mkEnableOption ''
        adb on PATH for ALVR's wired (usb) mode. ALVR prefers an adb on PATH
        and otherwise downloads google's platform-tools, which is a generic
        linux binary and won't run on NixOS
      '';
    };

    amdgpuHighPriority = lib.mkEnableOption ''
      a kernel patch letting any process create high priority amdgpu
      contexts.

      SteamVR's compositor needs one for async reprojection and asks for
      CAP_SYS_NICE to get it, but steam runs inside a bubblewrap user
      namespace on NixOS (no_new_privs), so file caps on vrcompositor-launcher
      never apply. Without this you still get VR, just no async reprojection
      and a nag popup on every launch.

      Costs: any local process can now starve the gpu scheduler, and the
      kernel is no longer the cached one from hydra, so every kernel bump
      is a full local build
    '';
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # steam comes from home-manager on these hosts, so the bits
      # programs.steam would normally switch on have to be done by hand.
      # 32-bit graphics is already on for deaddove, this just keeps the
      # module honest on any other host.
      hardware.graphics.enable32Bit = lib.mkDefault true;
      # udev rules for valve/htc/oculus usb devices (lighthouse dongles,
      # wired headsets, controllers) and the uinput module for steam input.
      # not needed for wireless-only ALVR, so turn it off if loading uinput
      # bugs you.
      hardware.steam-hardware.enable = lib.mkDefault true;
    }

    (lib.mkIf cfg.alvr.enable {
      programs.alvr = {
        enable = true;
        inherit (cfg.alvr) openFirewall;
      };
      environment.systemPackages = lib.optional cfg.alvr.wired pkgs.android-tools;
    })

    (lib.mkIf cfg.amdgpuHighPriority {
      boot.kernelPatches = [
        {
          name = "amdgpu-ctx-priority-for-everyone";
          patch = ./amdgpu-ctx-priority.patch;
        }
      ];
    })
  ]);
}
