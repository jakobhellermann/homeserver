{ ... }:

{
  imports = [
    ../../modules/services/monitoring.nix
    ../../modules/services/homeassistant.nix
    ../../modules/services/fava.nix
  ];

  services.monitoring = {
    enable = true;
    grafana.port = 3000;
    prometheus.port = 9090;
    loki.port = 3100;
    nginx = {
      virtualHost = "mel.local";
      path = "/grafana";
    };
  };

  services.homeassistant-container = {
    enable = true;
    port = 8123;
    openFirewall = true;
    dataDir = "/var/lib/homeassistant";
  };

  services.fava = {
    enable = true;
    port = 5000;
    repoUrl = "git@github.com:jakobhellermann/finances.git";
    beancountFile = "journal.beancount";
    nginx = {
      virtualHost = "mel.local";
      path = "/beancount";
    };
  };
}
