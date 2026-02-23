{ ... }:

{
  imports = [
    ../../modules/services/monitoring.nix
    ../../modules/services/homeassistant.nix
  ];

  services.monitoring = {
    enable = true;
    grafana.port = 3000;
    prometheus.port = 9090;
    loki.port = 3100;
    nginx.subdomain = "grafana.mel.local";
  };

  services.homeassistant-container = {
    enable = true;
    port = 8123;
    openFirewall = true;
    dataDir = "/var/lib/homeassistant";
    nginx.subdomain = "homeassistant.mel.local";
  };
}
