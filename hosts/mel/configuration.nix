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
    ./wifi.nix
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

  # Point agenix directly to persisted SSH keys since bind mounts aren't ready during activation
  # https://github.com/ryantm/agenix/pull/225
  age.identityPaths = [ "/persist/system/etc/ssh/ssh_host_ed25519_key" ];
  age.secrets.wifi-password-env.file = ../../secrets/wifi-password-env.age;
  age.secrets.ssh-github.file = ../../secrets/ssh-github.age;

  system.stateVersion = "26.06";
}
