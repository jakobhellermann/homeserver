# Homeserver Configuration

NixOS configuration for homeserver.

## Services

| Service        | Access                                                             | Data                     |
| -------------- | ------------------------------------------------------------------ | ------------------------ |
| Grafana        | [`mel.local/grafana`](http://mel.local/homeassistant)              | `/var/lib/grafana`       |
| Home Assistant | [`mel.local/homeassistant`](http://mel.local/homeassistant), :8123 | `/var/lib/homeassistant` |
| Fava           | [`mel.local/grafanancount`](http://mel.local/beancount)            | `/var/lib/fava`          |
| Paperless      | [`mel.local/paperless`](http://mel.local/paperless)                | `postgres`               |

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
