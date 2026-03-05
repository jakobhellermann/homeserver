{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;
let
  cfg = config.my.services.zigbee2mqtt;
  mqttPort = 1883;
  zmqtt2prom = inputs.zmqtt2prom.packages.${pkgs.system}.default;
in
{
  options.my.services.zigbee2mqtt = {
    enable = mkEnableOption "Zigbee2MQTT bridge";
    title = mkOption { type = types.str; };
    subdomain = mkOption { type = types.str; };
    port = mkOption {
      type = types.port;
      default = 1910;
    };
    serialPort = mkOption {
      type = types.str;
      default = "/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_e48a3415fbf0ef1199acc60a6d9880ab-if00-port0";
    };
    serialAdapter = mkOption {
      type = types.str;
      default = "ember";
    };
    openFirewall = mkOption {
      type = types.bool;
      default = false;
    };
    zmqtt2prom = {
      enable = mkEnableOption "zmqtt2prom Prometheus exporter for Zigbee2MQTT";
      port = mkOption {
        type = types.port;
        default = 9851;
        description = "HTTP port for Prometheus metrics";
      };
    };
  };

  config = mkIf cfg.enable {
    services.mosquitto.enable = true;

    services.zigbee2mqtt = {
      enable = true;
      settings = {
        version = 5;
        url = "https://zigbee2mqtt.mel.local";
        serial = {
          port = cfg.serialPort;
          adapter = cfg.serialAdapter;
          baudrate = 115200;
          rtscts = false;
        };

        frontend = {
          enabled = true;
          port = cfg.port;
        };

        homeassistant = {
          enabled = true;
          experimental_event_entities = true;
        };

        advanced = {
          log_level = "info";
          log_console_json = true;

          channel = 25;
          network_key = [
            99
            178
            209
            208
            8
            176
            205
            122
            140
            113
            86
            104
            166
            60
            4
            217
          ];
          pan_id = 47370;
          ext_pan_id = [
            229
            185
            187
            116
            181
            236
            220
            218
          ];
        };
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [
      cfg.port
      1883 # mosquitto MQTT
    ];

    services.nginx.virtualHosts."${cfg.subdomain}.${builtins.head config.my.domains}" = {
      serverAliases = map (d: "${cfg.subdomain}.${d}") (builtins.tail config.my.domains);
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        proxyWebsockets = true;
      };
    };

    systemd.services.zmqtt2prom = mkIf cfg.zmqtt2prom.enable {
      description = "Zigbee2MQTT Prometheus Exporter";
      wantedBy = [ "multi-user.target" ];
      after = [
        "mosquitto.service"
        "zigbee2mqtt.service"
      ];
      serviceConfig = {
        ExecStart = "${zmqtt2prom}/bin/zmqtt2prom --mqtt-host 127.0.0.1 --mqtt-port ${toString mqttPort} --http-port ${toString cfg.zmqtt2prom.port}";
        Restart = "on-failure";
        DynamicUser = true;
      };
    };

    my.services.monitoring.scrapeTargets = mkIf cfg.zmqtt2prom.enable [
      {
        name = "zmqtt2prom";
        address = "127.0.0.1:${toString cfg.zmqtt2prom.port}";
        job = "zigbee2mqtt";
        scrapeInterval = "15s";

      }
    ];
  };
}
