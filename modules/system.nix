{ config, ... }:

{
  imports = [ ./ssh-keys.nix ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  hardware.enableRedistributableFirmware = true;
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    tmp.cleanOnBoot = true;
  };
  time.timeZone = "Europe/Berlin";

  networking.nftables.enable = true;
  networking.firewall.enable = true;

  # ssh
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };
  networking.firewall.allowedTCPPorts = [ 22 ];
  users.users.root.openssh.authorizedKeys.keys = config.my.sshKeys;

  users.mutableUsers = false;
  security.sudo.wheelNeedsPassword = false;
}
