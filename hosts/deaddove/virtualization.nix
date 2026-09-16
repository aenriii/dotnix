{ inputs, pkgs, ... }:
{
  imports = [
    inputs.NixVirt.nixosModules.default
    ./vms
  ];

  virtualisation.libvirt = {
    enable = true;
    swtpm.enable = true;
  };
  
  environment.systemPackages = with pkgs; [
    qemu
    qemu_kvm
    qemu-utils
    libvirt
  ];
  
}