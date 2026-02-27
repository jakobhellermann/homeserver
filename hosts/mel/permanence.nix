{
  ...
}:
{
  environment.persistence.system = {
    persistentStoragePath = "/persist/system";
    directories = [
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/nixos" # https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/administration/nixos-state.section.md
      "/var/lib/systemd" # https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/administration/systemd-state.section.md
      "/etc/NetworkManager/system-connections"
      "/var/lib/containers"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
    users.mel = {
      files = [
        ".local/state/comma/choices"
      ];
    };
  };
  environment.persistence.services = {
    persistentStoragePath = "/persist/services";
    directories = [
    ];
  };
}
