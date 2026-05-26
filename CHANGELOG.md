# Changelog

All notable changes to plausible-quadlet-setup.

## [1.1.5] - 2026-05-25

### Fixed
- `DropCapability=ALL` combined with `AddCapability=` in quadlet units
  generates `--cap-drop all` (lowercase, space-separated) on some Podman
  versions. Podman misparses `all` as a container image name and tries to
  pull `docker.io/library/all:latest`.

  Root cause: quadlet generator lowercases the value and uses space
  separation instead of `--cap-drop=ALL`.

  Fix: removed `DropCapability=ALL` and `AddCapability=*` from
  `plausible-db.container` and `plausible-events-db.container`.
  Rootless Podman already excludes dangerous capabilities. postgres and
  clickhouse need CHOWN, FOWNER, SETUID, SETGID — all present in the
  default container capability set without any explicit grant.

  `plausible.container` retains `DropCapability=ALL` + `NoNewPrivileges=true`
  since the app container needs no capabilities at all.

## [1.1.4] - 2026-05-25

### Fixed
- Named volumes created implicitly by Podman on first container start were
  owned by root on the host when subuid was not yet configured at volume
  creation time. postgres (uid=999) and clickhouse (uid=101) could not
  write to their volumes: `find: /var/lib/postgresql/data: Permission denied`

### Added
- SECTION 7: explicit volume creation via `podman volume create` after
  `podman system migrate` — volumes now exist with correct UID mapping active
- `podman unshare chown` for each volume to set ownership to the container
  process UID inside the user namespace:
  - plausible-db → 999:999 (postgres)
  - plausible-clickhouse, plausible-clickhouse-logs → 101:101 (clickhouse)
  - plausible-data → 1000:1000 (plausible app)
- 5 new bats assertions covering volume creation and ownership

## [1.1.3] - 2026-05-25

### Fixed
- `DropCapability=ALL` + `NoNewPrivileges=true` on postgres and clickhouse
  containers prevented them from chowning their data/log directories on init.
  postgres needs CHOWN, FOWNER, SETUID, SETGID to switch to the postgres user.
  clickhouse needs CHOWN, FOWNER to chown /var/log/clickhouse-server.
  plausible app container retains full lockdown (DropCapability=ALL,
  NoNewPrivileges=true) — only the DB containers are relaxed.

## [1.1.2] - 2026-05-25

### Fixed
- `/etc/subuid` and `/etc/subgid` not provisioned — hard dependency for
  rootless Podman user namespace mapping. Without these entries Podman
  refuses to start rootless containers.

### Added
- SECTION 6 now calls `usermod --add-subuids` / `--add-subgids` for the
  service account if entries are not already present
- `podman system migrate` called after subuid/subgid setup to rewrite
  storage config to current UID mapping
- `PLAUSIBLE_SUBUID_START` / `PLAUSIBLE_SUBUID_COUNT` tunables (default
  2000000 / 65536) — override if range conflicts with existing users
- Preflight now validates `usermod --add-subuids` is supported
  (shadow-utils ≥ 4.6 required)
- 6 new bats assertions covering subuid/subgid/migrate behaviour
- README requirements updated: shadow-utils ≥ 4.6 added

## [1.1.0] - 2026-05-25

### Changed
- Full rebuild following fts-quadlet-setup/pbx-quadlet-setup conventions
- `quadlets/` → `containers/`, `networks/`, `volumes/` directories
- `config/` → `env/`, `examples/`
- Bind mounts → named Podman `.volume` units
- `setup.sh` → `plausible_setup.sh` POSIX sh bootstrapper with env-var tunables
- `EnvironmentFile=%h` not `/etc/`
- `DropCapability=ALL` + `NoNewPrivileges=true` on all container units
- `:Z` SELinux labels on all volume mounts
- `WantedBy=default.target` throughout
- `share/summary.m4` + `render` macro for all output
- `MOCK_DIR`-stubbed bats tests — no live podman/systemd/network
- `CLAUDE.md`, `CODEOWNERS`, `LICENSE`, `TODO.md` added
- CI: shellcheck → bats → GitHub Pages

## [1.0.1] - 2026-05-25

### Fixed
- Brace expansion in setup.sh (bash-only, not POSIX sh)
- Replaced setup.sh with thin make wrapper

## [1.0.0] - 2026-05-25

### Added
- Initial release (deprecated — use 1.1.0)
