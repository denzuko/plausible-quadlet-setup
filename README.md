# plausible-quadlet-setup

Podman quadlet for [Plausible Community Edition](https://plausible.io/docs/self-hosting) at `analytics.dapla.net`.

Follows the established Da Planet Security quadlet model: rootless user service, ZFS volumes, HAProxy reverse proxy, net.matrix labels.

## Stack

| Service | Image | Port |
|---|---|---|
| Plausible CE | `ghcr.io/plausible/community-edition:v2.1.4` | `127.0.0.1:8000` |
| PostgreSQL | `postgres:16-alpine` | internal |
| ClickHouse | `clickhouse/clickhouse-server:24.3.3.102-alpine` | internal |

## Prerequisites

- Podman 4.4+ with quadlet support
- ZFS pool named `storage`
- HAProxy (not Nginx)
- Rootless systemd services with linger

## Quick start

```sh
# 1. Provision ZFS, user, install quadlets
sudo sh scripts/setup.sh

# 2. Configure
cp config/plausible.env.example /srv/plausible/config/plausible.env
cp config/db.env.example /srv/plausible/config/db.env
# Edit both files — fill in secrets

# 3. Add HAProxy config
# Append config/haproxy-analytics.cfg to your HAProxy config

# 4. Start
su -s /bin/sh plausible -c 'systemctl --user daemon-reload'
su -s /bin/sh plausible -c 'systemctl --user start plausible'
```

## Tests

```sh
bats tests/plausible.bats
```

29 assertions covering: quadlet files, net.matrix labels, network isolation, port binding (localhost only), ZFS volume paths, restart policy, config templates, HAProxy config.

## ZFS layout

```
storage/containers/plausible  → /srv/plausible
  ├── data/          Plausible app data
  ├── db/            PostgreSQL data
  ├── clickhouse/    ClickHouse data
  ├── clickhouse-logs/
  └── config/        plausible.env, db.env (not committed)

storage/users/plausible       → /var/lib/plausible
```

## Versioning

Semver. MAJOR = breaking API/interface change. MINOR = new capability. PATCH = everything else.

Current: v1.0.0
