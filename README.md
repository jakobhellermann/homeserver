# Homeserver Configuration

NixOS configuration for homeserver.

## Services

| Service | Access | Data |
| ------- | ------ | ---- |

## Quick Commands

```bash
# Deploy configuration changes
just deploy

# SSH into the server
just ssh

# Create SSH tunnel for service access
just tunnel 1234

# Provision the server from scratch
just provision 192.168.178.100
```

## Backup

Backups are handled by [./hosts/mel/backup.nix](./hosts/mel/backup.nix) using [restic](https://restic.net).
There is one backup of the postgres DB tagged `db-postgres`, and one backup per service tagged `service` `foo`.

```bash

```

### Restore
