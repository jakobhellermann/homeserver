{
  config,
  lib,
  ...
}:

with lib;
let
  cfg = config.my.services.homeassistant;
in
{
  options.my.services.homeassistant = {
    enable = mkEnableOption "Home Assistant OCI container";
    title = mkOption { type = types.str; };
    subdomain = mkOption { type = types.str; };
    port = mkOption { type = types.port; };
    openFirewall = mkOption { type = types.bool; };
    dataDir = mkOption { type = types.str; };
    image = mkOption {
      type = types.str;
      default = "ghcr.io/home-assistant/home-assistant:stable";
    };
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
        "--cap-add=NET_RAW"
      ];
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [
      cfg.port
      1400 # https://www.home-assistant.io/integrations/sonos/#network-requirements
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
    ];

    my.nginx.${cfg.subdomain} = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        proxyWebsockets = true;
      };
    };
  };
}
