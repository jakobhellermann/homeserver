{ config, ... }:

{
  imports = [
    ../../modules/services/monitoring.nix
    ../../modules/services/homeassistant.nix
    ../../modules/services/fava.nix
    ../../modules/services/paperless.nix
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

  services.fava = {
    enable = true;
    port = 5000;
    repoUrl = "git@github.com:jakobhellermann/finances.git";
    beancountFile = "journal.beancount";
    sshKeyFile = config.age.secrets.ssh-github.path;
    nginx.subdomain = "fava.mel.local";
  };

  services.paperless-ngx = {
    enable = true;
    port = 28981;
    nginx.subdomain = "paperless.mel.local";
  };
}
