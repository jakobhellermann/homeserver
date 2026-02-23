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

  system.stateVersion = "26.06";
}
