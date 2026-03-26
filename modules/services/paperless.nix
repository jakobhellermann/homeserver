{
  config,
  lib,
  ...
}:

with lib;
let
  cfg = config.my.services.paperless;
in
{
  options.my.services.paperless = {
    enable = mkEnableOption "Paperless-NGX document management system";
    title = mkOption { type = types.str; };
    subdomain = mkOption { type = types.str; };
    port = mkOption {
      type = types.port;
      default = 28981;
    };
  };

  config = mkIf cfg.enable {
    services.paperless = {
      enable = true;
      port = cfg.port;
      domain = "${cfg.subdomain}.${config.my.primaryDomain}";

      # Use local PostgreSQL database
      database.createLocally = true;

      settings = {
        PAPERLESS_CONSUMER_IGNORE_PATTERN = [
          ".jj/*"
          "desktop.ini"
        ];
        PAPERLESS_OCR_LANGUAGE = "deu+eng";
        PAPERLESS_AUTO_LOGIN_USERNAME = "admin";
      };
    };

    my.nginx.${cfg.subdomain} = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        proxyWebsockets = true;
        extraConfig = ''
          # Increase timeouts for document processing
          proxy_read_timeout 300;
          proxy_connect_timeout 300;
          proxy_send_timeout 300;

          # Handle large file uploads
          client_max_body_size 100M;
        '';
      };
    };
  };
}
