output := "mel"
user := "mel"
host := "mel.local"
port := "22"

default:
    @just --list

check:
    nix build .#nixosConfigurations.mel.config.system.build.toplevel --dry-run

update:
    nix flake update

# Provision the configuration on a new nixos host, wiping the disk
provision host:
    nix run github:nix-community/nixos-anywhere -- --flake .#{{ output }} root@{{ host }} -p {{ port }}

# Deploy the configuration to a nixos host
deploy:
    NIX_SSHOPTS='-p {{ port }}' nix run nixpkgs#nixos-rebuild -- switch --flake .#{{ output }} --target-host root@{{ host }} --build-host root@{{ host }}

ssh *cmd:
    ssh {{ user }}@{{ host }} -p {{ port }} {{ cmd }}

scp from to=".":
    scp {{ user }}@{{ host }}:{{ from }} {{ to }}

tunnel port:
    ssh mel@{{ host }} -p {{ port }} -L {{ port }}:{{ host }}:{{ port }} -N
