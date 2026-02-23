{
  ...
}:

{
  environment.persistence.system = {
    persistentStoragePath = "/persist/system";
    # careful: adding a new path here will delete the existing content
    directories = [
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/nixos" # https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/administration/nixos-state.section.md
      "/var/lib/systemd" # https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/administration/systemd-state.section.md
      "/etc/NetworkManager/system-connections"
      "/var/cache"
      "/var/lib/containers"
      "/var/lib/tailscale"
      "/var/lib/acme"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
    users.mel = {
      directories = [
        ".cache"
      ];
      files = [
        ".bash_history"
        ".local/share/fish/fish_history"
        ".local/state/comma/choices"
      ];
    };
  };
  environment.persistence.services = {
    persistentStoragePath = "/persist/services";
    directories = [
      {
        directory = "/var/lib/private";
        mode = "0700";
      }
      "/var/lib/private/alloy"
      "/var/lib/grafana"
      "/var/lib/prometheus2"
      {
        directory = "/var/lib/loki";
        user = "loki";
        group = "loki";
        mode = "0755";
      }
      "/var/lib/homeassistant"
    ];
  };
}
