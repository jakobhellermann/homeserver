# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a NixOS homeserver configuration using Nix flakes for declarative infrastructure-as-code. The server (hostname: "mel") runs four main services: Home Assistant, a monitoring stack (Grafana/Loki/Prometheus), Fava (Beancount accounting interface), and Paperless-NGX (document management).

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
- **inputs**: nixpkgs (unstable), disko (disk partitioning), agenix (secrets management), impermanence (stateless system), nix-index-database (command-not-found)

### Directory Layout

```
hosts/mel/
├── configuration.nix          # System-level config (networking, users, SSH, Nginx)
├── disko.nix                  # Disk partitioning (1GB EFI + ext4 root)
├── custom-services.nix        # Service enablement with options
├── permanence.nix             # Impermanence configuration (persistent paths)
├── hardware-configuration.nix # Hardware-specific config
└── index-page.nix             # Dynamic landing page generator

modules/
├── tools.nix             # System packages (curl, git, htop, jq, neovim, ripgrep, etc.)
└── services/             # Custom NixOS service modules
    ├── homeassistant.nix
    ├── monitoring.nix
    ├── fava.nix
    └── paperless.nix

secrets/
└── ssh-github.age        # Encrypted GitHub SSH key (agenix)
```

### Custom Service Module Pattern

All custom services follow this pattern:

1. Define options using `mkOption` and `mkEnableOption` under `options.services.<name>`
2. Implementation in `config = mkIf cfg.enable { ... }`
3. Create systemd services with proper dependencies and paths
4. Services are configured in `hosts/mel/custom-services.nix` by setting options

Example:

```nix
services.fava = {
  enable = true;
  port = 5000;
  repoUrl = "git@github.com:jakobhellermann/finances.git";
  beancountFile = "journal.beancount";
  sshKeyFile = config.age.secrets.ssh-github.path;
  nginx.subdomain = "fava.mel.local";
};
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
- Persistent data in `/persist/services/var/lib/postgresql/`
- Accessed via subdomain `paperless.mel.local` through Nginx

### Networking & Access

- Server accessible at `mel.local` via mDNS (Avahi)
- Service subdomains published via Avahi (e.g., `grafana.mel.local`, `homeassistant.mel.local`)
- WiFi configured for "FRITZ!Box 6660 Cable TO" network (password: "bananenbrot")
- Firewall allows: 22 (SSH), 80 (HTTP), 443 (HTTPS), 5353 (mDNS)
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
  - `/var/lib/postgresql/` - Paperless database

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
- **Secrets Management**: Sensitive secrets (GitHub SSH key) are managed via agenix. WiFi password is still in plaintext in configuration.nix.
- **Backups**: No automatic backup configuration. Manually back up `/persist/system/` and `/persist/services/` before major changes.
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
2. Import module in `hosts/mel/custom-services.nix`
3. Enable and configure service in `hosts/mel/custom-services.nix`
4. Add Nginx virtual host with subdomain in the service module (see existing services for pattern)
5. Add subdomain to `serviceDescriptions` list in `hosts/mel/configuration.nix` for Avahi publishing
6. Add persistent directories to `hosts/mel/permanence.nix` if service needs stateful data
7. Update firewall rules in `hosts/mel/configuration.nix` if service needs direct external access
