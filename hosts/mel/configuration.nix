{ pkgs, lib, ... }:

let
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/7y7H/M64OslBJvrMA+s+eF1P4MJVf0hx/Gw4zoQXC"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/s4OVz67odrG1c2tww9XBoeZmv2on2bEo+qao81mt0"
  ];

  # Services (used for mdns and index page)
  serviceDescriptions = [
  ];
in
{
  imports = [
    ./hardware-configuration.nix
    ./custom-services.nix
    ./permanence.nix
    ../../modules/tools.nix
    (import ./disko.nix {
      device = "/dev/sda";
      inherit lib;
    })
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
      userServices = true; # to allow avahi-publish for "subdomains"
    };
  };

  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      80
      443
    ];
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
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  services.nginx = {
    enable = true;

    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    virtualHosts."mel.local" = {
      default = true;
      locations."/" = {
        root = import ./index-page.nix { inherit pkgs lib serviceDescriptions; };
        index = "index.html";
      };
    };
  };

  security.sudo.wheelNeedsPassword = false;

  users.users.root.openssh.authorizedKeys.keys = sshKeys;

  users.mutableUsers = false;

  users.users.mel = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = sshKeys;
  };

  # Publish subdomain CNAME records via Avahi
  systemd.services.avahi-publish-subdomains = {
    description = "Publish service subdomains via Avahi";
    after = [
      "avahi-daemon.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    partOf = [ "avahi-daemon.service" ];
    serviceConfig = {
      Type = "forking";
      ExecStart = pkgs.writeShellScript "avahi-publish-subdomains" ''
        IP=$(${pkgs.iproute2}/bin/ip -4 addr show | ${pkgs.gnugrep}/bin/grep -oP '(?<=inet\s)\d+(\.\d+){3}' | ${pkgs.gnugrep}/bin/grep -v 127.0.0.1 | head -n1)
        ${lib.concatMapStringsSep "\n" (svc: ''
          ${pkgs.avahi}/bin/avahi-publish -a ${svc.domain} -R $IP &
        '') serviceDescriptions}
      '';
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  system.stateVersion = "26.06";
}
