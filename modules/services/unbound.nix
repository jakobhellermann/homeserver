{ config, lib, ... }:

let
  cfg = config.my.services.unbound;
  tailscaleIP = "100.113.32.56";
  tailnet = "tail335875";
  domains = [
    {
      name = "mel.${tailnet}.ts.net";
      ip = tailscaleIP;
    }
    {
      name = "mel.home";
      ip = config.my.localIP;
    }
  ];
  subdomains = lib.mapAttrsToList (name: svc: svc.subdomain) (
    lib.filterAttrs (_name: svc: (svc.enable or false) && (svc ? subdomain)) config.my.services
  );
in
{
  options.my.services.unbound = {
    enable = lib.mkEnableOption "local DNS server for Tailscale subdomains";
  };

  config = lib.mkIf cfg.enable {
    services.unbound = {
      enable = true;
      settings = {
        server = {
          interface = [
            "127.0.0.1"
            "192.168.178.128"
            tailscaleIP
          ];
          access-control = [
            "127.0.0.0/8 allow"
            "192.168.178.0/24 allow"
            "100.64.0.0/10 allow" # Tailscale CGNAT range
          ];

          local-zone = map (d: ''"${d.name}." static'') domains;
          local-data =
            map (d: ''"${d.name}. A ${d.ip}"'') domains
            ++ lib.concatMap (d: map (sub: ''"${sub}.${d.name}. A ${d.ip}"'') subdomains) domains;
        };
      };
    };

    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.firewall.allowedTCPPorts = [ 53 ];
  };
}
