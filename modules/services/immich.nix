{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.immich-custom;
in
{
  options.services.immich-custom = {
    enable = mkEnableOption "Immich photo and video management system";
    port = mkOption {
      type = types.port;
      default = 2283;
    };
    nginx.subdomain = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    services.immich = {
      enable = true;
      port = cfg.port;
      host = "127.0.0.1";
      database.createDB = true;
      redis.enable = true;
    };

    services.nginx.virtualHosts."${cfg.nginx.subdomain}" = {
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
