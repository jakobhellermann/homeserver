{ config, ... }:

{
  imports = [
    ../../modules/services
    ../../modules/services/blocky.nix
    ../../modules/services/monitoring.nix
    ../../modules/services/homeassistant.nix
    ../../modules/services/zigbee2mqtt.nix
    ../../modules/services/fava.nix
    ../../modules/services/paperless.nix
    ../../modules/services/immich.nix
    ../../modules/services/minecraft.nix
    ../../modules/services/mediaserver.nix
  ];

  my.services.blocky = {
    enable = true;
    subdomain = "blocky";
  };

  my.services.monitoring = {
    enable = true;
    title = "Grafana";
    subdomain = "grafana";

    grafana.port = 3000;
    prometheus.port = 9090;
    loki.port = 3100;
  };

  my.services.homeassistant = {
    enable = true;
    title = "Home Assistant";
    subdomain = "homeassistant";
    port = 8123;
    openFirewall = true;
    dataDir = "/var/lib/homeassistant";
  };

  my.services.zigbee2mqtt = {
    enable = true;
    title = "Zigbee2MQTT";
    subdomain = "zigbee2mqtt";
    port = 1910;
    openFirewall = true;
    zmqtt2prom.enable = true;
  };

  my.services.fava = {
    enable = true;
    title = "Fava";
    subdomain = "fava";
    port = 5000;
    repoUrl = "git@github.com:jakobhellermann/finances.git";
    beancountFile = "journal.beancount";
    sshKeyFile = config.age.secrets.ssh-github.path;
  };

  my.services.paperless = {
    enable = true;
    title = "Paperless";
    subdomain = "paperless";
    port = 28981;
  };

  my.services.immich = {
    enable = true;
    title = "Immich";
    subdomain = "photos";
    port = 2283;
    exposePublic = true;
  };

  my.services.minecraft = {
    enable = true;
    autoStart = false;
    metrics.enable = true;
    # whitelist = {
    #   username = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
    # };
  };

  my.services.mediaserver = {
    enable = true;
    title = "Jellyfin";
    subdomain = "jellyfin";
    exposePublic = true;
  };

  my.primaryDomain = "mel.home";
  my.domains = {
    "mel.home" = { };
    "mel.local" = { };
    "mel.tail335875.ts.net" = { };
    "jjakobh.duckdns.org" = {
      public = true;
      acme = true;
    };
    "jjakobh.dedyn.io" = {
      public = true;
      acme = true;
    };
    "jjakobh.me" = {
      public = true;
    };
  };
  my.localIP = "192.168.178.128";
  my.tailscaleIP = "100.113.32.56";
  my.tailscale.advertiseRoutes = [ "${config.my.localIP}/32" ];
}
