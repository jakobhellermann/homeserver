# Homeserver Configuration

NixOS configuration for homeserver.

Accessible under

- [mel.local](http://mel.local) on local network using mDNS
- [mel.home](http://mel.home) when in [tailscale](https://tailscale.com) network
- [jjakobh.duckdns.org](http://jjakobh.duckdns.org) (only public services)

## Services

| Service        | Access                                                           | Data                               |
| -------------- | ---------------------------------------------------------------- | ---------------------------------- |
| Grafana        | [`grafana.mel.home`](http://grafana.mel.home)                    | `/var/lib/grafana`                 |
| Home Assistant | [`homeassistant.mel.home`](http://homeassistant.mel.home), :8123 | `/var/lib/homeassistant`           |
| Fava           | [`fava.mel.home`](http://fava.mel.home)                          | `/var/lib/fava`                    |
| Paperless      | [`paperless.mel.home`](http://paperless.mel.home)                | `postgres`                         |
| Immich         | [`immich.mel.home`](http://immich.mel.home)                      | `/var/lib/immich`, `postgres`      |
| Zigbee2MQTT    | [`zigbee2mqtt.mel.home`](http://zigbee2mqtt.mel.home)            | `/var/lib/{zigbee2mqtt,mosquitto}` |
| Jellyfin       | [`jellyfin.mel.home`](http://zigbee2mqtt.mel.home)               | `/var/lib/{media,jellyfin}`        |
| Minecraft      | `:25565`                                                         | `/var/lib/minecraft`               |

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
