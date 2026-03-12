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

  publicServices = lib.filterAttrs (_: cfg: cfg.exposePublic or false) config.my.services;
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

    virtualHosts = {
      "${builtins.head config.my.domains}" = {
        serverAliases = builtins.tail config.my.domains;
        locations."/" = {
          root = import ./index-page.nix {
            inherit pkgs lib;
            services = config.my.services;
          };
          index = "index.html";
        };
      };

      # Fallback for unknown hosts
      "_" = {
        default = true;
        locations."/" = notFound;
      };
    }
    // builtins.listToAttrs (
      map (domain: {
        name = "*.${domain}";
        value = {
          useACMEHost = domain;
          forceSSL = true;
          locations."/" = notFound;
        };
      }) config.my.publicDomains
    )
    // builtins.listToAttrs (
      map (domain: {
        name = domain;
        value = {
          useACMEHost = domain;
          forceSSL = true;
          locations."/" = {
            root = import ./index-page.nix {
              inherit pkgs lib;
              services = publicServices;
            };
            index = "index.html";
          };
        };
      }) config.my.publicDomains
    );
  };
}
