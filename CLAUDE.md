# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a NixOS homeserver configuration using Nix flakes for declarative infrastructure-as-code. The server (hostname: "mel") runs eight main services: Home Assistant, a monitoring stack (Grafana/Loki/Prometheus), Fava (Beancount accounting interface), Paperless-NGX (document management), Immich (photo/video management), Zigbee2MQTT (Zigbee bridge with Prometheus exporter), Minecraft (Fabric server), and Unbound (local DNS). Remote access is provided via Tailscale VPN.

## Essential Commands

### Development & Deployment

```bash
# Deploy configuration changes to remote server
just deploy

# Update flake dependencies
just update

# Provision server from scratch (destructive!)
just provision mel.local

# SSH into the server
just ssh
just ssh ls # run a command directly

# Create SSH tunnel for service access (substitute port)
just tunnel 8123

# Copy files from server
just scp /path/on/server /local/destination

# Edit encrypted secrets
just agenix ssh-github
```

### Testing Configuration

```bash
# Build configuration without deploying
nix build .#nixosConfigurations.mel.config.system.build.toplevel

# Evaluate specific configuration options
nix eval .#nixosConfigurations.mel.config.system.stateVersion
```

## Architecture

### Flake Structure

- **flake.nix**: Main entry point defining the `mel` NixOS configuration
- **flake.lock**: Pinned to nixos-unstable channel
- **inputs**: nixpkgs (unstable), disko (disk partitioning), agenix (secrets management), impermanence (stateless system), nix-index-database (command-not-found), zmqtt2prom (Zigbee2MQTT Prometheus exporter), nix-minecraft (Minecraft server management)

### Directory Layout

```
hosts/mel/
├── configuration.nix          # System-level config (networking, users, SSH, Nginx)
├── disko.nix                  # Disk partitioning (1GB EFI + ext4 root)
├── custom-services.nix        # Service enablement with options
├── permanence.nix             # Impermanence configuration (persistent paths)
├── backup.nix                 # Restic backup configuration
├── hardware-configuration.nix # Hardware-specific config
└── index-page.nix             # Dynamic landing page generator

modules/
├── tools.nix             # System packages (curl, git, htop, jq, neovim, ripgrep, etc.)
├── tailscale.nix         # Tailscale VPN configuration
└── services/             # Custom NixOS service modules
    ├── homeassistant.nix
    ├── monitoring.nix
    ├── fava.nix
    ├── paperless.nix
    ├── immich.nix
    ├── zigbee2mqtt.nix
    ├── minecraft.nix
    └── unbound.nix

secrets/
├── ssh-github.age        # Encrypted GitHub SSH key (agenix)
├── tailscale-authkey.age # Tailscale authentication key
├── restic-password.age   # Restic backup repository password
└── restic-env.age        # Restic environment variables (e.g., cloud storage credentials)
```

### Custom Service Module Pattern

All custom services follow this pattern:

1. Define options using `mkOption` and `mkEnableOption` under `options.my.services.<name>` (or `options.my.local-services.<name>` for non-networked services like Minecraft and Unbound)
2. Implementation in `config = mkIf cfg.enable { ... }`
3. Create systemd services with proper dependencies and paths
4. Services are configured in `hosts/mel/custom-services.nix` by setting options

Example:

```nix
my.services.fava = {
  enable = true;
  title = "Fava";
  subdomain = "fava";
  port = 5000;
  repoUrl = "git@github.com:jakobhellermann/finances.git";
  beancountFile = "journal.beancount";
  sshKeyFile = config.age.secrets.ssh-github.path;
};
```

Domains are configured via `my.domains` (a list; first entry is primary, the rest become `serverAliases`):

```nix
my.domains = [ "mel.local" "mel.home" "mel.tail335875.ts.net" ];
```

### Service Architecture

**Home Assistant** (port 8123)

- Runs as OCI container (ghcr.io/home-assistant/home-assistant:stable)
- Host networking mode for device discovery
- Persistent data in `/persist/services/var/lib/homeassistant/`
- Accessed via subdomain `homeassistant.mel.local` through Nginx

**Monitoring Stack** (ports 3000, 3100, 9090)

- Grafana (3000): Pre-provisioned with Node Exporter dashboard
- Loki (3100): Log aggregation from systemd journal via Alloy
- Prometheus (9090): Metrics collection with remote write capability
- Alloy: Forwarding agent (journal → Loki, node-exporter → Prometheus)
- Node Exporter (9100): System metrics
- Persistent data in `/persist/services/var/lib/grafana/`
- Accessed via subdomain `grafana.mel.local` through Nginx

**Fava** (port 5000)

- Python-based Beancount web interface using `uv` for dependency management
- Syncs from private GitHub repo on service start (fetch + hard reset)
- Uses SSH key authentication via agenix-managed secret
- SSH key encrypted in `secrets/ssh-github.age`, loaded via systemd credentials
- Repository cloned to `/var/lib/fava/` (persisted)
- Accessed via subdomain `fava.mel.local` through Nginx

**Paperless-NGX** (port 28981)

- Document management system with OCR capabilities
- Uses local PostgreSQL database (created automatically)
- OCR configured for German and English (`PAPERLESS_OCR_LANGUAGE = "deu+eng"`)
- Auto-login enabled for admin user
- Persistent data in `/persist/services/var/lib/paperless/` and `/persist/services/var/lib/postgresql/`
- Accessed via subdomain `paperless.mel.local` through Nginx

**Immich** (port 2283)

- Self-hosted photo and video management solution
- Uses NixOS native module (`services.immich`)
- PostgreSQL database for metadata (shared with Paperless)
- Redis for caching and job queues
- Optional Prometheus metrics via `IMMICH_TELEMETRY_INCLUDE`
- Persistent data in `/persist/services/var/lib/immich/` and `/persist/services/var/lib/redis-immich/`
- Accessed via subdomain `immich.mel.local` through Nginx
- Nginx configured with extended timeouts and 50GB upload limit for large media files

**Zigbee2MQTT** (port 1910, MQTT 1883)

- Zigbee bridge connecting Zigbee devices to Home Assistant via MQTT
- Uses Mosquitto as MQTT broker
- Serial device: Sonoff Zigbee 3.0 USB Dongle Plus V2 (`/dev/serial/by-id/...`, adapter: ember)
- Prometheus metrics via `zmqtt2prom` exporter (port 9851, scraped by Alloy)
- Home Assistant integration enabled (`experimental_event_entities = true`)
- Persistent data in `/persist/services/var/lib/zigbee2mqtt/` and `/persist/services/var/lib/mosquitto/`
- Accessed via subdomain `zigbee2mqtt.mel.local` through Nginx
- Firewall opens port 1910 and 1883 (MQTT) when `openFirewall = true`

**Minecraft** (port 25565)

- Fabric 1.21.11 server using `nix-minecraft` flake input
- Mods: Fabric API, FabricExporter (Prometheus metrics), Spark (profiler)
- Prometheus metrics scraped on port 25585
- `autoStart = false` — must be started manually
- Uses `systemd-socket` management system (no tmux)
- Persistent data in `/persist/services/var/lib/minecraft/` (owned by `minecraft:minecraft`)
- Configured under `my.local-services.minecraft` (not `my.services.*`)
- `openFirewall = true` is set by the `nix-minecraft` module itself

**Unbound** (port 53)

- Local DNS server for subdomain resolution across all configured domains
- Resolves `*.mel.local`, `*.mel.home`, and `*.mel.tail335875.ts.net` to server IPs
- Listens on localhost, local network (192.168.178.128), and Tailscale IP (100.113.32.56)
- Access control: localhost, local network (192.168.178.0/24), Tailscale CGNAT range (100.64.0.0/10)
- Dynamically generates DNS records for all enabled services
- Configured under `my.local-services.unbound`

### Networking & Access

- Server accessible at `mel.local` via mDNS (Avahi)
- Service subdomains published via Avahi (e.g., `grafana.mel.local`, `homeassistant.mel.local`, `immich.mel.local`)
- **Tailscale**: VPN mesh network for remote access, authenticated via `tailscale-authkey.age` secret
- WiFi configured for "FRITZ!Box 6660 Cable TO" network (password: "bananenbrot")
- Firewall allows: 22 (SSH), 53 (DNS for Unbound), 80 (HTTP), 443 (HTTPS), 5353 (mDNS), plus Tailscale UDP port
- Nginx reverse proxy routes subdomain traffic to services (all services bind to localhost only)
- SSH authentication via authorized_keys (password auth disabled for SSH)
- Root and `mel` user share same SSH keys
- Local `mel` user password set to "local" for console login

### Persistence & State

This system uses **impermanence** for a stateless root filesystem with explicit persistence.

**Persistent directories:**

- `/persist/system/` - System state (managed by `environment.persistence.system`)
  - `/var/log/` - System logs
  - `/var/lib/nixos/` - NixOS state
  - `/var/lib/systemd/` - Systemd state
  - `/var/lib/bluetooth/` - Bluetooth pairings
  - `/var/lib/containers/` - Container state
  - `/etc/NetworkManager/system-connections/` - WiFi credentials
  - SSH host keys (`/etc/ssh/ssh_host_ed25519_key`)

- `/persist/services/` - Service data (managed by `environment.persistence.services`)
  - `/var/lib/homeassistant/` - Home Assistant configuration and database
  - `/var/lib/grafana/` - Grafana dashboards and settings
  - `/var/lib/fava/` - Cloned finance repository
  - `/var/lib/postgresql/` - PostgreSQL database (used by Paperless and Immich)
  - `/var/lib/paperless/` - Paperless documents and data
  - `/var/lib/immich/` - Immich photo/video library, uploads, and profiles
  - `/var/lib/redis-immich/` - Redis data for Immich
  - `/var/lib/zigbee2mqtt/` - Zigbee2MQTT config and device database
  - `/var/lib/mosquitto/` - Mosquitto MQTT broker data
  - `/var/lib/minecraft/` - Minecraft server world and config (owned by `minecraft:minecraft`)

- `/persist/system/` also includes:
  - `/var/lib/tailscale/` - Tailscale VPN state
  - `/var/lib/loki/` - Loki log storage
  - `/var/lib/prometheus2/` - Prometheus metrics data
  - `/var/lib/private/alloy/` - Alloy state

**Important:** Everything not in `/persist/` is ephemeral and will be lost on reboot.

### Secrets Management

Secrets are managed using **agenix** and encrypted with the server's SSH host key.

**Setup process:**

1. Server SSH host key is persisted at `/persist/system/etc/ssh/ssh_host_ed25519_key`
2. Secrets are encrypted in `secrets/*.age` files using this key
3. During activation, agenix reads from the persisted location via `age.identityPaths`
4. Decrypted secrets are made available to services (e.g., Fava's GitHub SSH key)

**Editing secrets:**

```bash
just agenix ssh-github  # Edit the GitHub SSH key secret
```

The GitHub SSH key is loaded into Fava service via systemd's `LoadCredential` directive.

## Important Notes

- **Destructive Operations**: `just provision` will wipe the target server. Always use `just deploy` for updates.
- **Secrets Management**: Sensitive secrets (GitHub SSH key, Tailscale auth key, Restic credentials) are managed via agenix. WiFi password is still in plaintext in configuration.nix.
- **Backups**: Automatic daily backups via Restic to `/persist/backup/`. Backed up items:
  - Per-database PostgreSQL dumps (paperless, immich)
  - Home Assistant data
  - Immich library, uploads, and profiles
  - Paperless documents
  - Retention: 14 daily, 4 weekly, 2 monthly snapshots
- **Impermanence**: Root filesystem is ephemeral. Only explicitly persisted paths survive reboots. Always add new stateful data to `permanence.nix`.
- **CRITICAL - Persistence Directories**: NEVER create, modify, or delete anything in `/persist/` directories on the server without EXPLICIT MANUAL APPROVAL from the user. This includes `/persist/system/` and `/persist/services/`. These directories contain critical persistent state that survives reboots. Always ask before touching them.
- **CRITICAL - Imperative Server Operations**: NEVER run imperative commands that modify server state (permissions, ownership, file manipulation, etc.) without EXPLICIT MANUAL APPROVAL from the user first. This includes commands like `chmod`, `chown`, `mkdir`, `rm`, etc. Always ask before executing such operations. Service restarts via `systemctl restart` are allowed.
- **Service Isolation**: All services currently run as root or with elevated privileges.
- **Python Dependencies**: Fava uses `uv` to manage Python packages. `programs.nix-ld.enable = true` is required for dynamic binaries.
- **Subdomain Resolution**: Service subdomains are published via Avahi mDNS by the `avahi-publish-subdomains` systemd service.

## Modifying Services

When changing service modules:

1. Update the module in `modules/services/<name>.nix`
2. Modify options in `hosts/mel/custom-services.nix` if needed
3. Run `just deploy` to apply changes
4. Check service status: `just ssh systemctl status <service-name>`
5. View logs: `just ssh journalctl -u <service-name> -f`

When adding new services:

1. Create module in `modules/services/<name>.nix` following existing pattern
   - Use `options.my.services.<name>` for services exposed via Nginx
   - Use `options.my.local-services.<name>` for non-web services (e.g., Minecraft, Unbound)
2. Import module in `hosts/mel/custom-services.nix`
3. Enable and configure service in `hosts/mel/custom-services.nix`
4. Add Nginx virtual host with subdomain in the service module (see existing services for pattern)
   - Use `builtins.head config.my.domains` for primary host, `builtins.tail config.my.domains` for aliases
5. Add subdomain to `serviceDescriptions` list in `hosts/mel/configuration.nix` for Avahi publishing
6. Add persistent directories to `hosts/mel/permanence.nix` if service needs stateful data
7. Update firewall rules in `hosts/mel/configuration.nix` if service needs direct external access
