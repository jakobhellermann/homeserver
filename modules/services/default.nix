{ lib, ... }:

{
  options.my.domains = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.public = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this is a public (internet-facing) domain. Public domains only serve services with exposePublic = true.";
        };
        options.acme = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this domain needs ACME TLS certificates";
        };
      }
    );
    description = "All domains for this server, with public/acme flags";
  };
  options.my.nginx = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.exposePublic = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to also serve this on public domains";
        };
        options.locations = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Nginx location blocks for this subdomain (passed to virtualHosts.*.locations)";
        };
        options.extraConfig = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Extra nginx config at the vhost level";
        };
      }
    );
    default = { };
    description = "Nginx reverse proxy entries keyed by subdomain. Assembled into virtualHosts by the nginx module.";
  };
  options.my.primaryDomain = lib.mkOption {
    type = lib.types.str;
    description = "Primary local domain used for service URLs (e.g., mel.home)";
  };
  options.my.localIP = lib.mkOption {
    type = lib.types.str;
    description = "Local IP address of the server on the LAN";
  };
  options.my.tailscaleIP = lib.mkOption {
    type = lib.types.str;
    description = "Tailscale IP address of the server";
  };
}
