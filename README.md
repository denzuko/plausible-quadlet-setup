# plausible-quadlet-setup

Rootless Podman quadlet for [Plausible CE](https://plausible.io/docs/self-hosting)
at `analytics.dapla.net`. Follows the `fts-quadlet-setup` / `pbx-quadlet-setup`
conventions exactly.

## Install

```sh
curl -fsSL https://denzuko.github.io/plausible-quadlet-setup/plausible_setup.sh | doas sh
```

Or with make:

```sh
NS=$(mktemp -d)
git clone --depth=1 https://github.com/denzuko/plausible-quadlet-setup "$NS"
make -C "$NS" install
```

## Requirements

- Podman ≥ 4.4
- systemd ≥ 252
- ZFS pool named `storage`
- HAProxy (not Nginx)
- `m4`, `openssl`

## Stack

| Service | Image |
|---|---|
| Plausible CE | `ghcr.io/plausible/community-edition:v2.1.4` |
| PostgreSQL | `docker.io/postgres:16-alpine` |
| ClickHouse | `docker.io/clickhouse/clickhouse-server:24.3` |

> Note: postgres and clickhouse have no GHCR mirror — docker.io is used
> for these two only.

## After install

1. Edit `~plausible/.config/containers/systemd/plausible.env`
   — set `DATABASE_URL` password, `SMTP_*` values
2. Edit `~plausible/.config/containers/systemd/db.env`
   — set `POSTGRES_PASSWORD`
3. Add `examples/haproxy-plausible.cfg` snippet to HAProxy config
4. `machinectl shell plausible@ -- systemctl --user start plausible`

## ZFS layout

```
storage/containers/plausible  → /srv/plausible   (data, volumes)
storage/users/plausible       → /var/lib/plausible
```

## Tests

```sh
make test
```

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `PLAUSIBLE_USER` | `plausible` | Service account name |
| `PLAUSIBLE_UID` | `2010` | Service account UID |
| `PLAUSIBLE_VERSION` | `v2.1.4` | Version tag for ZFS snapshot |
| `ZFS_POOL` | `storage` | ZFS pool name |
| `PLAUSIBLE_UNINSTALL` | `0` | Set to `1` to uninstall |

## Versioning

Semver. MAJOR = breaking interface change. MINOR = new capability. PATCH = fixes.
