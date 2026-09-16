{ inputs, lib, ... }:
let
  call = lib.flip import { inherit inputs; libvirt = inputs.NixVirt.lib; };
  libvirt = inputs.NixVirt.lib;
in {
  virtualisation.libvirt.connections."qemu:///system" = {
    pools = [
      {
        definition = libvirt.pool.writeXML {
          name = "default";
          uuid = "537dede5-1d8d-44fa-a4e5-cfe786cc992e";
          type = "dir";
          target.path = "/home/aenri/VMs/disks";
        };
        active = true;
      }
    ];
    domains = [
      (call ./ubuntu-desktop.nix)
      (call ./ubuntu-server.nix)
    ];
  };
}