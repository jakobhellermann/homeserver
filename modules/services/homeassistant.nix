{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.homeassistant-container;
in
{
  options.services.homeassistant-container = {
    enable = mkEnableOption "Home Assistant OCI container";
    port = mkOption { type = types.port; };
    openFirewall = mkOption { type = types.bool; };
    dataDir = mkOption { type = types.str; };
    image = mkOption {
      type = types.str;
      default = "ghcr.io/home-assistant/home-assistant:stable";
    };
    nginx.subdomain = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.homeassistant = {
      image = cfg.image;
      volumes = [
        "${cfg.dataDir}:/config"
      ];
      environment.TZ = config.time.timeZone or "UTC";
      ports = [
        "${toString cfg.port}:8123"
      ];
      extraOptions = [
        "--network=host"
      ];
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [
      cfg.port
      1400 # https://www.home-assistant.io/integrations/sonos/#network-requirements
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
    ];

    services.nginx.virtualHosts."${cfg.nginx.subdomain}" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        proxyWebsockets = true;
      };
    };
  };
}
