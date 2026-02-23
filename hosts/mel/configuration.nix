{ pkgs, ... }:

let
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/7y7H/M64OslBJvrMA+s+eF1P4MJVf0hx/Gw4zoQXC"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/s4OVz67odrG1c2tww9XBoeZmv2on2bEo+qao81mt0"
  ];
in
{
  imports = [
    (import ./disko.nix { device = "/dev/sda"; })
    ../../modules/tools.nix
  ];

  # host
  networking.hostName = "mel";
  time.timeZone = "Europe/Berlin";

  networking.networkmanager = {
    enable = true;
    ensureProfiles.profiles = {
      home-wifi = {
        connection = {
          id = "home-wifi";
          type = "wifi";
        };
        wifi = {
          mode = "infrastructure";
          ssid = "FRITZ!Box 6660 Cable TO";
        };
        wifi-security = {
          auth-alg = "open";
          key-mgmt = "wpa-psk";
          psk = "bananenbrot";
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };
  };
  hardware.enableRedistributableFirmware = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      workstation = true;
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    allowedUDPPorts = [ 5353 ]; # mDNS
  };

  boot = {
    tmp.cleanOnBoot = true;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # services

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  security.sudo.wheelNeedsPassword = false;

  users.users.root.openssh.authorizedKeys.keys = sshKeys;

  users.users.mel = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = sshKeys;
  };

  system.stateVersion = "26.06";
}
