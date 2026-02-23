{ config, lib, ... }:

with lib;

let
  cfg = config.services.monitoring;
  prometheusNodeExporterPort = 9100;
in
{
  options.services.monitoring = {
    enable = mkEnableOption "monitoring stack (Grafana + Loki + Prometheus)";
    grafana.port = mkOption { type = types.port; };
    loki.port = mkOption { type = types.port; };
    prometheus.port = mkOption { type = types.port; };
    nginx = {
      path = mkOption { type = types.str; };
      virtualHost = mkOption { type = types.str; };
    };
  };

  config = mkIf cfg.enable {
    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_port = cfg.grafana.port;
          http_addr = "127.0.0.1";
          root_url = "http://mel.local/grafana";
          serve_from_sub_path = true;
        };
        security = {
          admin_user = "admin";
          admin_password = "$__file{/run/grafana/admin-password}";
          secret_key = "$__file{/run/grafana/secret-key}";
        };
        "auth.anonymous" = {
          enabled = true;
          org_role = "Admin";
        };
      };

      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://localhost:${toString cfg.loki.port}";
            isDefault = true;
          }
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://localhost:${toString cfg.prometheus.port}";
          }
        ];
        dashboards.settings.providers = [
          {
            name = "Dashboards";
            options.path = ./dashboards;
          }
        ];
      };
    };

    systemd.services.grafana.preStart = ''
      mkdir -p /run/grafana
      echo "admin" > /run/grafana/admin-password
      chmod 600 /run/grafana/admin-password

      if [ ! -f /run/grafana/secret-key ]; then
        tr -dc A-Za-z0-9 </dev/urandom | head -c 32 > /run/grafana/secret-key
        chmod 600 /run/grafana/secret-key
      fi
    '';

    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;

        server.http_listen_port = cfg.loki.port;

        common = {
          path_prefix = "/var/lib/loki";
          replication_factor = 1;
          ring = {
            instance_addr = "127.0.0.1";
            kvstore.store = "inmemory";
          };
        };

        schema_config = {
          configs = [
            {
              from = "2026-01-01";
              store = "tsdb";
              schema = "v13";
              object_store = "filesystem";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
        };
      };
    };

    services.prometheus = {
      enable = true;
      port = cfg.prometheus.port;
      listenAddress = "127.0.0.1";
      extraFlags = [ "--web.enable-remote-write-receiver" ];
      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = prometheusNodeExporterPort;
        };
      };
    };

    services.alloy = {
      enable = true;
    };

    environment.etc."alloy/config.alloy".text = ''
      loki.relabel "journal" {
        forward_to = []

        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "service"
        }

        rule {
          source_labels = ["__journal__boot_id"]
          target_label  = "boot_id"
        }

        rule {
          source_labels = ["__journal__transport"]
          target_label  = "transport"
        }

        rule {
          source_labels = ["__journal_priority_keyword"]
          target_label  = "level"
        }
      }

      loki.source.journal "read" {
        forward_to    = [loki.write.endpoint.receiver]
        relabel_rules = loki.relabel.journal.rules
        labels        = {job = "systemd-journal"}
      }

      loki.write "endpoint" {
        endpoint {
          url = "http://127.0.0.1:${toString cfg.loki.port}/loki/api/v1/push"
        }
      }

      prometheus.scrape "node" {
        targets = [{
          "__address__" = "127.0.0.1:${toString prometheusNodeExporterPort}",
        }]
        forward_to = [prometheus.remote_write.local.receiver]
        job_name = "node"
      }

      prometheus.remote_write "local" {
        endpoint {
          url = "http://127.0.0.1:${toString cfg.prometheus.port}/api/v1/write"
        }
      }
    '';

    services.nginx.virtualHosts."${cfg.nginx.virtualHost}".locations."${cfg.nginx.path}/" = {
      proxyPass = "http://127.0.0.1:${toString cfg.grafana.port}";
      proxyWebsockets = true;
    };
  };
}
