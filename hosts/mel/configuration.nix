{ pkgs, lib, ... }:

let
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/7y7H/M64OslBJvrMA+s+eF1P4MJVf0hx/Gw4zoQXC"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/s4OVz67odrG1c2tww9XBoeZmv2on2bEo+qao81mt0"
  ];

  # List of subdomains to publish via mDNS
  mdnsSubdomains = [
    "grafana.mel.local"
    "homeassistant.mel.local"
    "fava.mel.local"
  ];
in
{
  imports = [
    (import ./disko.nix { device = "/dev/sda"; })
    ../../modules/tools.nix
    ./custom-services.nix
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

  # Enable nix-ld to run dynamic binaries (needed for uv)
  programs.nix-ld.enable = true;

  # services

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
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
        return = "200 '${builtins.readFile ./index.html}'";
        extraConfig = ''
          add_header Content-Type "text/html; charset=utf-8";
        '';
      };
    };
  };

  security.sudo.wheelNeedsPassword = false;

  users.users.root.openssh.authorizedKeys.keys = sshKeys;

  users.users.mel = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = sshKeys;
  };

  # Generate and persist SSH key for GitHub access
  systemd.services.setup-github-key = {
    description = "Setup SSH key for GitHub";
    wantedBy = [ "multi-user.target" ];
    before = [ "fava.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /root/.ssh
      mkdir -p /persist/ssh

      # Generate key in persistent storage if it doesn't exist
      if [ ! -f /persist/ssh/github_id_ed25519 ]; then
        ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f /persist/ssh/github_id_ed25519 -N "" -C "root@mel"
        echo "=== NEW SSH PUBLIC KEY FOR GITHUB ==="
        cat /persist/ssh/github_id_ed25519.pub
        echo "Add this key to: https://github.com/settings/keys"
        echo "======================================"
      fi

      # Link to /root/.ssh
      ln -sf /persist/ssh/github_id_ed25519 /root/.ssh/id_ed25519
      ln -sf /persist/ssh/github_id_ed25519.pub /root/.ssh/id_ed25519.pub
      chmod 600 /persist/ssh/github_id_ed25519
    '';
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
        ${lib.concatMapStringsSep "\n" (subdomain: ''
          ${pkgs.avahi}/bin/avahi-publish -a ${subdomain} -R $IP &
        '') mdnsSubdomains}
      '';
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  system.stateVersion = "26.06";
}
