output := "mel"
user := "mel"
host := "mel.local"
port := "22"

default:
    @just --list

update:
    nix flake update

eval args:
    nix eval .#nixosConfigurations.mel.{{ args }}

check name="mel":
    nix build .#nixosConfigurations.{{ name }}.config.system.build.toplevel --dry-run

# Provision the configuration on a new nixos host, wiping the disk
provision host:
    nix run github:nix-community/nixos-anywhere -- --flake .#{{ output }} root@{{ host }} -p {{ port }}

deploy *args:
    NIX_SSHOPTS='-p {{ port }}' nix run nixpkgs#nixos-rebuild -- switch --flake .#{{ output }} --target-host root@{{ host }} --build-host root@{{ host }} {{ args }}

ssh *cmd:
    ssh {{ user }}@{{ host }} -p {{ port }} "{{ cmd }}"

scp from to=".":
    scp {{ user }}@{{ host }}:{{ from }} {{ to }}

reboot:
    @just ssh sudo reboot

restart service:
    @just ssh sudo systemctl restart {{ service }}

logs service *args:
    @just ssh journalctl -u {{ service }} --boot --no-pager {{ args }}

tunnel local_port:
    ssh mel@{{ host }} -p {{ port }} -L {{ local_port }}:localhost:{{ local_port }} -N
