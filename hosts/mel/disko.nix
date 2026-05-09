{
  device ? throw "Set this to your disk device, e.g. /dev/sda",
}:

{ utils, ... }:

{
  disko.devices = {
    disk = {
      main = {
        inherit device;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Override existing partition
                subvolumes = {
                  # Ephemeral root - will be recreated on each boot
                  "/root" = {
                    mountpoint = "/";
                  };
                  # Persistent storage
                  "/persist" = {
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                    mountpoint = "/persist";
                  };
                  # Nix store
                  "/nix" = {
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                    mountpoint = "/nix";
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  fileSystems."/persist".neededForBoot = true;

  # Boot-time root rotation for impermanence (systemd stage 1)
  boot.initrd.systemd.services.rollback-root = {
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
    requiredBy = [ "initrd.target" ];
    before = [ "sysroot.mount" ];
    requires = [ "${utils.escapeSystemdPath "/dev/disk/by-partlabel/disk-main-root"}.device" ];
    after = [
      "${utils.escapeSystemdPath "/dev/disk/by-partlabel/disk-main-root"}.device"
      "local-fs-pre.target"
    ];
    script = ''
      mkdir -p /btrfs_tmp
      mount /dev/disk/by-partlabel/disk-main-root /btrfs_tmp

      delete_subvolume_recursively() {
          IFS=$'\n'
          for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
              delete_subvolume_recursively "/btrfs_tmp/$i"
          done
          btrfs subvolume delete "$1"
      }

      # Prune old roots first so a >30-day-old current root isn't pruned
      # in the same boot it gets moved into old_roots.
      if [[ -d /btrfs_tmp/old_roots ]]; then
          for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
              delete_subvolume_recursively "$i"
          done
      fi

      if [[ -e /btrfs_tmp/root ]]; then
          mkdir -p /btrfs_tmp/old_roots
          timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
          mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
      fi

      btrfs subvolume create /btrfs_tmp/root
      umount /btrfs_tmp
    '';
  };
}
