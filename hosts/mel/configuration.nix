{
  config,
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
    (import ./disko.nix { device = "/dev/sda"; })
  ];

  networking.hostName = name;

  users.users.${name} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = config.my.sshKeys;
  };

  system.stateVersion = "26.06";
}
