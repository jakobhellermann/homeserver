{
  config,
  lib,
  ...
}:

with lib;
let
  cfg = config.my.services.immich;
  apiMetricsPort = 2284;
  microservicesMetricsPort = 2285;
in
{
  options.my.services.immich = {
    enable = mkEnableOption "Immich photo and video management system";
    title = mkOption { type = types.str; };
    subdomain = mkOption { type = types.str; };
    port = mkOption {
      type = types.port;
      default = 2283;
    };
    metrics.enable = mkEnableOption "Prometheus metrics";
  };

  config = mkIf cfg.enable {
    services.immich = {
      enable = true;
      port = cfg.port;
      host = "127.0.0.1";
      database.createDB = true;
      redis.enable = true;
      environment = mkIf cfg.metrics.enable {
        IMMICH_TELEMETRY_INCLUDE = "all";
        IMMICH_API_METRICS_PORT = toString apiMetricsPort;
        IMMICH_MICROSERVICES_METRICS_PORT = toString microservicesMetricsPort;
      };
    };

    my.services.monitoring.scrapeTargets = mkIf cfg.metrics.enable [
      {
        name = "immich_api";
        address = "127.0.0.1:${toString apiMetricsPort}";
        job = "immich-api";
      }
      {
        name = "immich_microservices";
        address = "127.0.0.1:${toString microservicesMetricsPort}";
        job = "immich-microservices";
      }
    ];

    services.nginx.virtualHosts."${cfg.subdomain}.${builtins.head config.my.domains}" = {
      serverAliases = map (d: "${cfg.subdomain}.${d}") (builtins.tail config.my.domains);
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        proxyWebsockets = true;
        extraConfig = ''
          # Increase timeouts for photo/video uploads
          proxy_read_timeout 600;
          proxy_connect_timeout 600;
          proxy_send_timeout 600;

          # Handle large file uploads
          client_max_body_size 50000M;
        '';
      };
    };
  };
}
