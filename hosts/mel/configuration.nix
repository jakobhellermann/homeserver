{
  config,
  lib,
  ...
}:

let
  name = "mel";
in
{
  imports = [
    ../../modules/mdns.nix
    ../../modules/system.nix
    ../../modules/tools.nix
    ./custom-services.nix
    ./hardware-configuration.nix
    ./nginx
    ./permanence.nix
    (import ./disko.nix {
      device = "/dev/sda";
      inherit lib;
    })
  ];

  networking.hostName = name;

  users.users.${name} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = config.my.sshKeys;
  };

  system.stateVersion = "26.06";
}
