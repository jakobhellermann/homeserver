{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.my.services.minecraft;
  metricsPort = 25585;
  operators = {
    dubi_steinkek = "2ae2a747-e589-4039-ba5a-462c28b58956";
  };
in
{
  options.my.services.minecraft = {
    enable = mkEnableOption "Minecraft server";
    port = mkOption {
      type = types.port;
      default = 25565;
    };
    metrics.enable = mkEnableOption "Prometheus metrics";
    # todo
    whitelist = mkOption {
      type = types.attrsOf types.str;
      default = { };
    };
    autoStart = mkOption {
      type = types.bool;
      default = true;
    };
  };

  config = mkIf cfg.enable {
    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "minecraft-server" ];

    services.minecraft-servers = {
      enable = true;
      eula = true;
      dataDir = "/var/lib/minecraft";
      openFirewall = true;

      servers.main = {
        enable = true;

        managementSystem.tmux.enable = false;
        managementSystem.systemd-socket.enable = true;

        package = pkgs.fabricServers.fabric-1_21_11;
        autoStart = cfg.autoStart;
        inherit operators;

        symlinks = {
          mods = pkgs.linkFarmFromDrvs "mods" (
            builtins.attrValues {
              Fabric-API = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/i5tSkVBH/fabric-api-0.141.3%2B1.21.11.jar";
                sha512 = "c20c017e23d6d2774690d0dd774cec84c16bfac5461da2d9345a1cd95eee495b1954333c421e3d1c66186284d24a433f6b0cced8021f62e0bfa617d2384d0471";
              };
              FabricExporter = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/dbVXHSlv/versions/D7LrQrIU/fabricexporter-1.0.20.jar";
                sha512 = "7d6ac1aabaf22a62f331735670db15cb0d66e9bc06aa2f94a65c6f01877e27fbc498ae9d6e305aa307aa3b91b317df6ee3ae843bfc380e6d1a9486b8e331b6bf";
              };
              Spark = pkgs.fetchurl {
                url = "https://cdn.modrinth.com/data/l6YH9Als/versions/1CB3cS0m/spark-1.10.156-fabric.jar";
                sha512 = "c17995968561761e0857445e28e9235f3c0ec5fc0695deda3b2ae408baf074348822f0a8671791032b32c6b2977edba1024a2cc3b4588b9274e7f131795af6e0";
              };
            }
          );
        };
      };
    };

    my.services.monitoring.scrapeTargets = mkIf cfg.metrics.enable [
      {
        name = "minecraft";
        address = "127.0.0.1:${toString metricsPort}";
        job = "minecraft";
      }
    ];
  };
}
