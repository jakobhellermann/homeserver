{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.my.services.mediaserver;
  mediaGroup = "media";
  mediaDir = "/var/lib/media";
in
{
  options.my.services.mediaserver = {
    enable = mkEnableOption "Media server stack (Jellyfin, Sonarr, Radarr, Prowlarr, Bazarr, Transmission)";
    title = mkOption { type = types.str; };
    subdomain = mkOption { type = types.str; };

    exposePublic = mkEnableOption "expose this service on public domains with HTTPS";

    jellyfin.port = mkOption {
      type = types.port;
      default = 8096;
    };
    sonarr.port = mkOption {
      type = types.port;
      default = 8989;
    };
    radarr.port = mkOption {
      type = types.port;
      default = 7878;
    };
    prowlarr.port = mkOption {
      type = types.port;
      default = 9696;
    };
    bazarr.port = mkOption {
      type = types.port;
      default = 6767;
    };
    transmission.port = mkOption {
      type = types.port;
      default = 9091;
    };
    seerr.port = mkOption {
      type = types.port;
      default = 5055;
    };
  };

  config = mkIf cfg.enable {
    # Shared media group for all services
    users.groups.${mediaGroup} = { };

    # Jellyfin
    services.jellyfin = {
      enable = true;
      group = mediaGroup;
    };

    # Hardware transcoding for Intel Alder Lake-N
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver # VAAPI driver for Broadwell and newer
        intel-compute-runtime # OpenCL for newer processors
        vpl-gpu-rt # Intel Video Processing Library
      ];
    };
    # Use the newer iHD driver
    systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "iHD";

    environment.systemPackages = with pkgs; [ jellyfin-ffmpeg ];

    # Sonarr (TV shows)
    services.sonarr = {
      enable = true;
      group = mediaGroup;
    };

    # Radarr (Movies)
    services.radarr = {
      enable = true;
      group = mediaGroup;
    };

    # Prowlarr (Indexer manager)
    services.prowlarr.enable = true;

    # Bazarr (Subtitles)
    services.bazarr = {
      enable = true;
      group = mediaGroup;
      listenPort = cfg.bazarr.port;
    };

    # Transmission (Torrent client)
    services.transmission = {
      enable = true;
      group = mediaGroup;
      settings = {
        rpc-bind-address = "127.0.0.1";
        rpc-port = cfg.transmission.port;
        rpc-host-whitelist-enabled = false;
        download-dir = "${mediaDir}/downloads";
        incomplete-dir = "${mediaDir}/downloads/.incomplete";
        incomplete-dir-enabled = true;
        watch-dir = "${mediaDir}/torrents";
        watch-dir-enabled = true;
        umask = 2; # 002 - group writable
      };
    };

    # Create media directories and Seerr data dir
    systemd.tmpfiles.rules = [
      "d ${mediaDir} 0775 root ${mediaGroup} -"
      "d ${mediaDir}/movies 0775 root ${mediaGroup} -"
      "d ${mediaDir}/tv 0775 root ${mediaGroup} -"
      "d ${mediaDir}/downloads 0775 root ${mediaGroup} -"
      "d ${mediaDir}/downloads/.incomplete 0775 root ${mediaGroup} -"
      "d ${mediaDir}/torrents 0775 root ${mediaGroup} -"
    ];

    # Ensure tmpfiles run before transmission starts
    systemd.services.transmission.after = [ "systemd-tmpfiles-setup.service" ];
    systemd.services.transmission.requires = [ "systemd-tmpfiles-setup.service" ];

    # Seerr (Request management for Sonarr/Radarr)
    virtualisation.oci-containers.containers.seerr = {
      image = "ghcr.io/seerr-team/seerr:latest";
      volumes = [
        "/var/lib/seerr:/app/config"
      ];
      environment = {
        TZ = config.time.timeZone or "UTC";
        LOG_LEVEL = "info";
        PORT = toString cfg.seerr.port;
      };
      extraOptions = [
        "--network=host"
      ];
    };

    # Nginx reverse proxies
    my.nginx = {
      ${cfg.subdomain} = {
        exposePublic = cfg.exposePublic;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.jellyfin.port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_read_timeout 600s;
            proxy_send_timeout 600s;
            proxy_connect_timeout 600s;
            proxy_buffering off;
            client_max_body_size 0;
          '';
        };
      };

      sonarr.locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.sonarr.port}";
        proxyWebsockets = true;
      };

      radarr.locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.radarr.port}";
        proxyWebsockets = true;
      };

      prowlarr.locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.prowlarr.port}";
        proxyWebsockets = true;
      };

      bazarr.locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.bazarr.port}";
        proxyWebsockets = true;
      };

      transmission = {
        locations."/" = {
          return = "301 $scheme://$host/transmission/web/";
        };
        locations."/transmission" = {
          proxyPass = "http://127.0.0.1:${toString cfg.transmission.port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_pass_header X-Transmission-Session-Id;
          '';
        };
      };

      seerr.locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.seerr.port}";
        proxyWebsockets = true;
      };
    };

  };
}
