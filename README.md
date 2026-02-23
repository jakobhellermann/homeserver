# Homeserver Configuration

NixOS configuration for homeserver.

## Services

| Service | Access                                                | Data               |
| ------- | ----------------------------------------------------- | ------------------ |
| Grafana | [`mel.local/grafana`](http://mel.local/homeassistant) | `/var/lib/grafana` |

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
