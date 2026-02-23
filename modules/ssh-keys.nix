{ lib, ... }:
{
  options.my.sshKeys = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/7y7H/M64OslBJvrMA+s+eF1P4MJVf0hx/Gw4zoQXC"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/s4OVz67odrG1c2tww9XBoeZmv2on2bEo+qao81mt0"
    ];
    description = "Authorized SSH public keys";
  };
}
