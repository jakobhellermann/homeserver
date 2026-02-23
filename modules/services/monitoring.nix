{ config, lib, ... }:

with lib;
let
  cfg = config.my.services.monitoring;
  prometheusNodeExporterPort = 9100;
  defaultScrapeInterval = "15s";
in
{
  options.my.services.monitoring = {
    enable = mkEnableOption "monitoring stack (Grafana + Loki + Prometheus)";
    title = mkOption { type = types.str; };
    subdomain = mkOption { type = types.str; };
    grafana.port = mkOption { type = types.port; };
    loki.port = mkOption { type = types.port; };
    prometheus.port = mkOption { type = types.port; };
    scrapeTargets = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            name = mkOption { type = types.str; };
            address = mkOption { type = types.str; };
            job = mkOption { type = types.str; };
            scrapeInterval = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Scrape interval (e.g. '15s'). Uses Alloy default if null.";
            };
            scrapeTimeout = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Scrape timeout (e.g. '5s'). Must be <= scrapeInterval.";
            };
          };
        }
      );
      default = [ ];
      description = "Additional Prometheus scrape targets";
    };
  };

  config = mkIf cfg.enable {
    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_port = cfg.grafana.port;
          http_addr = "127.0.0.1";
          root_url = "http://${cfg.subdomain}.${builtins.head config.my.domains}";
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
        dashboards = {
          default_home_dashboard_path = "${./dashboards}/server-essentials.json";
        };

        # Disable telemetry
        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
          check_for_plugin_updates = false;
        };

        # Disable unused features
        news.news_feed_enabled = false;
        snapshots.enabled = false;
        unified_alerting.enabled = false;

        panels.disable_sanitize_html = true;
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
              scrape_interval = "${defaultScrapeInterval}"
            }

      ${concatMapStringsSep "\n" (target: ''
        prometheus.scrape "${target.name}" {
          targets = [{
            "__address__" = "${target.address}",
          }]
          forward_to = [prometheus.remote_write.local.receiver]
          job_name = "${target.job}"
          scrape_interval = "${
            if target.scrapeInterval != null then target.scrapeInterval else defaultScrapeInterval
          }"
          ${optionalString (target.scrapeTimeout != null) "scrape_timeout = \"${target.scrapeTimeout}\""}
        }
      '') cfg.scrapeTargets}
            prometheus.remote_write "local" {
              endpoint {
                url = "http://127.0.0.1:${toString cfg.prometheus.port}/api/v1/write"
              }
            }
    '';

    services.nginx.virtualHosts."${cfg.subdomain}.${builtins.head config.my.domains}" = {
      serverAliases = map (d: "${cfg.subdomain}.${d}") (builtins.tail config.my.domains);
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.grafana.port}";
        proxyWebsockets = true;
      };
    };
  };
}
