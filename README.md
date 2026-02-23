# Homeserver Configuration

NixOS configuration for homeserver.

Accessible under

- [mel.local](http://mel.local) on local network using mDNS
- [mel.home](http://mel.home) when in [tailscale](https://tailscale.com) network

## Services

| Service        | Access                                                             | Data                     |
| -------------- | ------------------------------------------------------------------ | ------------------------ |
| Grafana        | [`grafana.mel.local`](http://grafana.mel.local)                    | `/var/lib/grafana`       |
| Home Assistant | [`homeassistant.mel.local`](http://homeassistant.mel.local), :8123 | `/var/lib/homeassistant` |
| Fava           | [`fava.mel.local`](http://fava.mel.local)                          | `/var/lib/fava`          |

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

```sh
restic snapshots # list snapshots
restic ls $id # list files
restic diff $from $to # diff changes
restic stats --tag $tag --mode raw-data # show compression ratio

sudo systemctl start restic-backups-service.service # trigger manually
```

### Restore

#### Files

```sh
# stop relevant services
sudo systemctl stop $service

# dry run, optionally with select path
restic restore "$snapshot:/persist/services/var/lib/immich/library/admin/2026/02-27" --dry-run -vv --target /
```

#### Postgres

```sh
# stop relevant services
sudo systemctl stop $service

restic snapshots --tag db
restic restore "$snapshot" --target . # restore ./immich.sql

sudo -u postgres psql -d immich < ./immich.sql
```
