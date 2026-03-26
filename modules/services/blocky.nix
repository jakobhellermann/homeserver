{ config, lib, ... }:

let
  cfg = config.my.services.blocky;
  metricsPort = 4000;
  tailscaleIP = config.my.tailscaleIP;
  tailnet = "tail335875";

  routerIP = "192.168.178.1";

  tailscaleClientIPs = {
    "mel" = "100.113.32.56";
    "jj" = "100.75.136.80";
    "oneplus-13r" = "100.73.6.88";
    "sipgatejj" = "100.88.82.118";
  };

  # todo: refactor away
  localDomains = [
    {
      name = "mel.${tailnet}.ts.net";
      ip = tailscaleIP;
    }
    {
      name = "mel.home";
      ip = config.my.localIP;
    }
  ];

  subdomains = builtins.attrNames config.my.nginx;

  # Build customDNS mapping: base domains + all service subdomains for each domain
  customDNSMapping = lib.listToAttrs (
    map (d: {
      name = d.name;
      value = d.ip;
    }) localDomains
    ++ lib.concatMap (
      d:
      map (sub: {
        name = "${sub}.${d.name}";
        value = d.ip;
      }) subdomains
    ) localDomains
  );
in
{
  options.my.services.blocky = {
    enable = lib.mkEnableOption "Blocky DNS proxy with ad-blocking";
    subdomain = lib.mkOption { type = lib.types.str; };
  };

  config = lib.mkIf cfg.enable {
    services.blocky = {
      enable = true;
      settings = {
        ports.dns = [
          "127.0.0.1:53"
          "${config.my.localIP}:53"
          "${tailscaleIP}:53"
        ];
        ports.http = "127.0.0.1:${toString metricsPort}";

        prometheus.enable = true;

        upstreams = {
          groups.default = [
            "tcp-tls:dns3.digitalcourage.de"
            "https://one.one.one.one/dns-query"
          ];
          strategy = "parallel_best"; # parallel_best, random, strict
        };

        bootstrapDns = [
          { upstream = "https://1.1.1.1/dns-query"; }
        ];

        customDNS = {
          customTTL = "1h";
          mapping = customDNSMapping;
        };

        blocking = {
          denylists.ads = [
            "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
          ];
          clientGroupsBlock.default = [ "ads" ];
        };

        caching = {
          # minTime = "5m";
          # maxTime = "30m";
          # prefetching = true;
        };

        clientLookup = {
          upstream = routerIP;
          clients = lib.mapAttrs (name: ip: [ ip ]) tailscaleClientIPs;
        };
      };
    };

    my.services.monitoring.scrapeTargets = [
      {
        name = "blocky";
        address = "127.0.0.1:${toString metricsPort}";
        job = "blocky";
      }
    ];

    my.nginx.blocky = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString metricsPort}";
      };
    };

    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.firewall.allowedTCPPorts = [ 53 ];
  };
}
