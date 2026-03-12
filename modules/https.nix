{
  config,
  pkgs,
  lib,
  ...
}:
let
  domainDuckDNS = "jjakobh.duckdns.org";
  domainDesec = "jjakobh.dedyn.io";
  configTemplate = builtins.toJSON {
    settings = [
      {
        provider = "duckdns";
        domain = domainDuckDNS;
        token = "$DUCKDNS_TOKEN";
        ip_version = "ipv6";
      }
      {
        provider = "desec";
        domain = domainDesec;
        token = "$DESEC_TOKEN";
        ip_version = "ipv6";
      }
      {
        provider = "desec";
        domain = "*.${domainDesec}";
        token = "$DESEC_TOKEN";
        ip_version = "ipv6";
      }
    ];
  };
in
{
  config.services.ddns-updater = {
    enable = true;
    environment.CONFIG_FILEPATH = "/run/ddns-updater-config/config.json";
  };

  config.systemd.services.ddns-updater = {
    serviceConfig = {
      EnvironmentFile = [
        config.age.secrets.duckdns-token-env.path
        config.age.secrets.desec-token-env.path
      ];
      RuntimeDirectory = "ddns-updater-config";
      RuntimeDirectoryMode = "0700";
      ExecStartPre = pkgs.writeShellScript "ddns-updater-config" ''
        printf '%s' ${lib.escapeShellArg configTemplate} | ${pkgs.envsubst}/bin/envsubst > /run/ddns-updater-config/config.json
      '';
    };
  };

  config.my.publicDomains = [
    domainDuckDNS
    domainDesec
  ];

  config.security.acme = {
    acceptTerms = true;
    defaults.email = "jakob.hellermann@protonmail.com";
  };

  config.security.acme.certs.${domainDuckDNS} = {
    domain = "*.${domainDuckDNS}";
    extraDomainNames = [ domainDuckDNS ];
    environmentFile = config.age.secrets.duckdns-token-env.path;
    dnsProvider = "duckdns";
    dnsResolver = "1.1.1.1:53";
    group = "nginx";
  };

  config.security.acme.certs.${domainDesec} = {
    domain = "*.${domainDesec}";
    extraDomainNames = [ domainDesec ];
    environmentFile = config.age.secrets.desec-token-env.path;
    dnsProvider = "desec";
    dnsResolver = "1.1.1.1:53";
    group = "nginx";
  };
}
