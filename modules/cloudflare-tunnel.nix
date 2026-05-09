{ config, ... }:

{
  age.secrets.cloudflare-tunnel-certificate.file = ../secrets/cloudflare-tunnel-certificate.age;
  age.secrets.cloudflare-tunnel-credentials.file = ../secrets/cloudflare-tunnel-credentials.age;

  services.cloudflared = {
    enable = true;
    certificateFile = config.age.secrets.cloudflare-tunnel-certificate.path;

    tunnels."mel-public" = {
      credentialsFile = config.age.secrets.cloudflare-tunnel-credentials.path;
      ingress = {
        "jjakobh.me" = {
          service = "http://localhost:80";
        };
        "*.jjakobh.me" = {
          service = "http://localhost:80";
        };
      };
      default = "http_status:404";
    };
  };
}
