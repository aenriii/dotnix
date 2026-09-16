{ libvirt, ... }:
let
  vmUuid = "5947daec-b7e2-44eb-a2bf-e69117e3ffa3";
in {
  definition = libvirt.domain.writeXML (libvirt.domain.templates.linux {
    name = "ubuntu-desktop";
    uuid = vmUuid;
    memory = { count = 4; unit = "GiB"; };
    storage_vol = { pool = "default"; volume = "${vmUuid}.qcow2"; };
    install_vol = "/home/aenri/VMs/ISOs/ubuntu-lts-26.iso";
    nvram_path = "/home/aenri/VMs/nvram/${vmUuid}.fd";
  });
}