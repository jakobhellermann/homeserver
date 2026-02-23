{ ... }:

{
  imports = [
    ../../modules/services/monitoring.nix
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
}
