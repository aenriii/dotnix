{ inputs, ... }:
{
  imports = [
    inputs.NixVirt.nixosModules.default
    ./vms
  ];

  virtualisation.libvirt = {
    enable = true;
    swtpm.enable = true;
  };
  
  
}