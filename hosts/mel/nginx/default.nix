{
  config,
  pkgs,
  lib,
  ...
}:

let
  notFound = {
    return = "404 'Not Found'";
    extraConfig = ''
      default_type text/plain;
    '';
  };

  publicAccessLog = ''
    access_log syslog:server=unix:/dev/log,tag=nginx_public public;
  '';

  domains = config.my.domains;
  trustedDomains = lib.filterAttrs (_: d: !d.public) domains;
  publicDomains = lib.filterAttrs (_: d: d.public) domains;
  publicEntries = lib.filterAttrs (_: e: e.exposePublic) config.my.nginx;

  allServices = config.my.services;
  publicServices = lib.filterAttrs (_: cfg: cfg.exposePublic or false) allServices;

  # Build a virtualHost from an nginx entry
  mkVhost =
    entry:
    {
      inherit (entry) locations;
    }
    // lib.optionalAttrs (entry.extraConfig != "") {
      inherit (entry) extraConfig;
    };

  mkVhostWithAcme =
    domain: entry:
    mkVhost entry
    // {
      extraConfig = entry.extraConfig + publicAccessLog;
    }
    // lib.optionalAttrs domains.${domain}.acme {
      useACMEHost = domain;
      forceSSL = true;
    };

  trustedDomainNames = builtins.attrNames trustedDomains;
  primaryTrusted = builtins.head trustedDomainNames;
  aliasTrusted = builtins.tail trustedDomainNames;

  trustedVhosts = lib.mapAttrs' (subdomain: entry: {
    name = "${subdomain}.${primaryTrusted}";
    value = mkVhost entry // {
      serverAliases = map (d: "${subdomain}.${d}") aliasTrusted;
    };
  }) config.my.nginx;

  # For public domains: each domain gets its own vhost per exposed subdomain
  publicVhosts = lib.listToAttrs (
    lib.concatMap (
      domain:
      map (subdomain: {
        name = "${subdomain}.${domain}";
        value = mkVhostWithAcme domain publicEntries.${subdomain};
      }) (builtins.attrNames publicEntries)
    ) (builtins.attrNames publicDomains)
  );

  # Wildcard fallback for public domains (404 for non-exposed subdomains)
  publicWildcardVhosts = lib.listToAttrs (
    map (domain: {
      name = "*.${domain}";
      value = {
        locations."/" = notFound;
        extraConfig = publicAccessLog;
      }
      // lib.optionalAttrs domains.${domain}.acme {
        useACMEHost = domain;
        forceSSL = true;
      };
    }) (builtins.attrNames publicDomains)
  );

  # Root domain index pages
  trustedRootVhost = {
    "${primaryTrusted}" = {
      serverAliases = aliasTrusted;
      locations."/" = {
        root = import ./index-page.nix {
          inherit pkgs lib;
          services = allServices;
        };
        index = "index.html";
      };
    };
  };

  publicRootVhosts = lib.listToAttrs (
    map (domain: {
      name = domain;
      value = {
        locations."/" = {
          root = import ./index-page.nix {
            inherit pkgs lib;
            services = publicServices;
          };
          index = "index.html";
        };
        extraConfig = publicAccessLog;
      }
      // lib.optionalAttrs domains.${domain}.acme {
        useACMEHost = domain;
        forceSSL = true;
      };
    }) (builtins.attrNames publicDomains)
  );
in

{
  networking.firewall = {
    allowedTCPPorts = [
      80
      443
    ];
  };

  services.nginx = {
    enable = true;

    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    commonHttpConfig = ''
      log_format public '$http_cf_connecting_ip - $remote_user [$time_local] '
                        '"$request" $status $body_bytes_sent '
                        '"$http_referer" "$http_user_agent" '
                        'host=$host';
    '';

    virtualHosts =
      trustedVhosts
      // publicVhosts
      // publicWildcardVhosts
      // trustedRootVhost
      // publicRootVhosts
      // {
        # Fallback for unknown hosts
        "_" = {
          default = true;
          locations."/" = notFound;
          extraConfig = publicAccessLog;
        };
      };
  };
}
