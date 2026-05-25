# CLAUDE.md

Context file for Claude Code and Claude chat when working with
`plausible-quadlet-setup`.

---

## Project Overview

`plausible-quadlet-setup` deploys [Plausible CE](https://plausible.io/docs/self-hosting)
as rootless Podman quadlet units managed by systemd. Sibling project to
`fts-quadlet-setup` and `pbx-quadlet-setup` — follows identical conventions.

**Operator:** Da Planet Security / Dwight Spencer (`denzuko@dapla.net`)
**Target:** analytics.dapla.net
**License:** BSD 2-Clause

---

## Repository Layout

```
plausible-quadlet-setup/
├── plausible_setup.sh            # Bootstrapper — entry point
├── Makefile                      # lint / test / install / uninstall
├── containers/
│   ├── plausible.container
│   ├── plausible-db.container
│   └── plausible-events-db.container
├── networks/
│   └── plausible.network
├── volumes/
│   ├── plausible-data.volume
│   ├── plausible-db.volume
│   ├── plausible-clickhouse.volume
│   └── plausible-clickhouse-logs.volume
├── env/
│   ├── plausible.env
│   └── db.env
├── examples/
│   └── haproxy-plausible.cfg
├── share/
│   └── summary.m4
└── tests/
    └── plausible_setup.bats
```

---

## Key Conventions (match fts-quadlet-setup exactly)

- **POSIX sh only** in `plausible_setup.sh` — no bashisms.
  Verify with `shellcheck -S style plausible_setup.sh`.
- **ZFS:** `compression=lz4`, `atime=off`. Snapshot at install.
  `storage/containers/plausible` → `/srv/plausible`
  `storage/users/plausible` → `/var/lib/plausible`
- **`useradd --no-create-home`** — ZFS dataset is the home dir.
- **EnvironmentFile=%h** not `/etc/` — user-relative path.
- **WantedBy=default.target** — not `multi-user.target`.
- **DropCapability=ALL + NoNewPrivileges=true** on every container unit.
- **Volume mounts: `:Z`** SELinux label on all volumes.
- **Named Podman volumes** via `.volume` units — no bind mounts to host paths.
- **Networking:** all inter-container traffic on `plausible.network`.
  Containers address each other by `ContainerName=`.
- **Secrets:** generated with `openssl rand -base64 64`. Never in templates.
- **Idempotency:** `plausible_setup.sh` safe to re-run. Env files not
  overwritten if present. Only `SECRET_KEY_BASE` stamped on first install.
- **Image exception:** `docker.io/postgres` and `docker.io/clickhouse` —
  no GHCR mirror exists for these. Noted here explicitly.
- **`render <macro>`** for all installer output — never bare `printf` summary blocks.
- **Tests:** `MOCK_DIR` stubs for id/useradd/loginctl/zfs/machinectl/openssl.
  No live podman, systemd, or network in tests.

## What Claude Should Not Do

- Do not use `--create-home` with `useradd`
- Do not add CLI flag parsing — all config via environment variables
- Do not use bash-specific syntax in `plausible_setup.sh`
- Do not add bind mounts to host paths in container units
- Do not store secrets in `env/` templates
- Do not write tests requiring live podman, systemd, or network
- Do not use `docker-compose` or `podman-compose` — quadlet-native only
- Do not replicate CHANGELOG entries into TODO
