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
# One-liner install from repo
mdo env NS=$(mktemp -d) REPO="https://github.com/denzuko/plausible-quadlet-setup" PS1="% " sh
git clone --depth=1 $REPO $NS
make -C $NS install
```

Or clone and run manually:

```sh
git clone https://github.com/denzuko/plausible-quadlet-setup
cd plausible-quadlet-setup

# Provision ZFS, user, install quadlets, stage config templates
make install

# Edit config — fill in secrets
$EDITOR /srv/plausible/config/plausible.env
$EDITOR /srv/plausible/config/db.env

# Add HAProxy snippet then start
make start
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
