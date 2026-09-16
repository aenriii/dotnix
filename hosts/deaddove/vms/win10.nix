{ libvirt, ... }:
let
  vmUuid = "46e6ae23-ac98-416f-81c0-1241189c7584";
in {
  definition = libvirt.domain.writeXML (libvirt.domain.templates.windows {
    name = "windows-10";
    uuid = vmUuid;
    memory = { count = 6; unit = "GiB"; };
    storage_vol = { pool = "default"; volume = "${vmUuid}.qcow2"; };
    install_vol = "/home/aenri/VMs/ISOs/win10-cons-22H2.iso";
    nvram_path = "/home/aenri/VMs/nvram/${vmUuid}.fd";
  });
}