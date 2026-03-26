{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      workstation = true;
      userServices = true; # to allow avahi-publish for "subdomains"
    };
  };

  networking.firewall = {
    allowedUDPPorts = [ 5353 ];
  };

  # Publish subdomain CNAME records via Avahi
  systemd.services.avahi-publish-subdomains = lib.mkIf (config.my.nginx != { }) {
    description = "Publish service subdomains via Avahi";
    after = [
      "avahi-daemon.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    partOf = [ "avahi-daemon.service" ];
    serviceConfig = {
      Type = "forking";
      ExecStart = pkgs.writeShellScript "avahi-publish-subdomains" ''
        IP=$(${pkgs.iproute2}/bin/ip -4 addr show | ${pkgs.gnugrep}/bin/grep -oP '(?<=inet\s)\d+(\.\d+){3}' | ${pkgs.gnugrep}/bin/grep -v 127.0.0.1 | head -n1)
        ${lib.concatStringsSep "\n" (
          map (subdomain: ''
            ${pkgs.avahi}/bin/avahi-publish -a ${subdomain}.mel.local -R $IP &
          '') (builtins.attrNames config.my.nginx)
        )}
      '';
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
}
