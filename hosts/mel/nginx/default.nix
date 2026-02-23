{
  config,
  pkgs,
  lib,
  ...
}:

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

    virtualHosts."${builtins.head config.my.domains}" = {
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
    virtualHosts."_" = {
      default = true;
      locations."/" = {
        return = "404 'Not Found'";
        extraConfig = ''
          default_type text/plain;
        '';
      };
    };
  };
}
