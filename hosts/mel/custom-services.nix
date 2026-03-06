{ config, ... }:

{
  imports = [
    ../../modules/services
    ../../modules/services/blocky.nix
  ];

  my.services.blocky = {
    enable = true;
    subdomain = "blocky";
  };

  my.domains = [
    "mel.home"
    "mel.local"
    "mel.tail335875.ts.net"
  ];
  my.localIP = "192.168.178.128";
  my.tailscaleIP = "100.113.32.56";
  my.tailscale.advertiseRoutes = [ "${config.my.localIP}/32" ];
}
