{ libvirt, ... }:
let
  vmUuid = "85b8315b-0916-4e0f-b659-51fbb6f93079";
in {
  definition = libvirt.domain.writeXML libvirt.domain.templates.linux {
    name = "ubuntu-server";
    uuid = vmUuid;
    memory = { count = 4; unit = "GiB"; };
    storage_vol = { pool = "default"; volume = "${vmUuid}.qcow2"; };
    install_vol = "/home/aenri/VMs/ISOs/ubuntu-server-lts-26.04.1.iso";
    nvram_path = "/home/aenri/VMs/nvram/${vmUuid}.fd";
  };
}