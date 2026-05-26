# Changelog

All notable changes to plausible-quadlet-setup.

## [1.2.2] - 2026-05-25

### Changed
- ClickHouse config bind-mounted from ZFS dataset (/srv/plausible/etc/clickhouse/)
  instead of quadlet config dir. Tunable from host without container rebuild.

### Fixed
- low-resources.xml tuned for memory-constrained hosts (~16GB RAM, swap pressure):
  - max_server_memory_usage: 4GB hard cap
  - max_server_memory_usage_to_ram_ratio: 0.5
  - mark_cache_size: 512MB
  Without these limits ClickHouse will OOM on hosts with <2GB free RAM.

## [1.2.1] - 2026-05-25

### Changed
- ClickHouse updated: 24.3.3.102-alpine → 24.12-alpine
  (matches plausible/community-edition:v3.2.1 compose.yml exactly)
  amd64 digest: sha256:58a8168a0a17a5694172cbe89b8d3f1f6c9a91182260c98e299e87da1b0d0d0b

### Added
- ClickHouse config files from plausible/community-edition:v3.2.1 clickhouse/
  Required for v3.x — profile settings changed in v3.2.0:
  - clickhouse/low-resources.xml
  - clickhouse/default-profile-low-resources-overrides.xml
  - clickhouse/ipv4-only.xml
  - clickhouse/logs.xml
  Mounted read-only at /etc/clickhouse-server/config.d/
  Installer copies to %h/.config/containers/systemd/clickhouse/

## [1.2.0] - 2026-05-25

### Changed
- Plausible CE updated to v3.2.1 (was v2.1.4)
  amd64 digest: sha256:7450d9df4bfce160541d65bdba6bd4bcdd9a6db07f13dde91060705fa242c650
  index digest: sha256:33e60bfb40f2df5da00f8753b76fad04f67dba3abe6d73eb516e440e3fb62985

## [1.1.9] - 2026-05-25

### Fixed
- Plausible image digest was the OCI image index (multi-arch manifest list)
  digest, not the platform-specific manifest digest. Podman 5.x rejects
  index digests with "invalid checksum digest length" (the error message
  truncates the digest in output — the value in the file was correct).

  Wrong (OCI index): sha256:4c2553516d09e3c7b1b9c39cca04a04c28c871f525adc8dbb7a2a8a20fed0857
  Correct (amd64):   sha256:59ffee982deb849a2749eef206005e475e688d59fa053858d75420d95cddb8e8

  To get the correct platform digest:
    skopeo inspect --raw docker://ghcr.io/plausible/community-edition:v2.1.4 | \
      python3 -c "import sys,json; [print(m['digest']) for m in json.load(sys.stdin)['manifests'] if m.get('platform',{}).get('architecture')=='amd64']"

## [1.1.8] - 2026-05-25

### Fixed
- `DropCapability=ALL` definitively confirmed as a Podman 5.4.x quadlet generator
  bug — value is lowercased to `all` in the generated `--cap-drop all` flag
  regardless of unit file casing. Removed from DB containers permanently.
  Documented with note to revisit when upstream fixes the generator.
  (plausible app container unaffected — it uses DropCapability=ALL + NoNewPrivileges=true
  which generates correctly because NoNewPrivileges is processed differently)

- Dependency restart propagation: plausible did not restart when DB services
  recovered because `Requires=` only stops dependents, it does not restart them.
  Added `BindsTo=plausible-db.service` and `BindsTo=plausible-events-db.service`
  to plausible.container. BindsTo causes plausible to stop when a DB stops and
  restart when the DB returns (combined with Restart=always).

## [1.1.7] - 2026-05-25

### Security
- All container images pinned to tag + SHA256 digest — prevents supply chain
  attacks via tag mutation (e.g. compromised :latest or floating alpine tags)
  - postgres: 16-alpine3.23@sha256:16bc17c6...
  - clickhouse: 24.3.3.102-alpine@sha256:8312f0ee... (amd64)
  - plausible: v2.1.4@sha256:4c255351...
- plausible-db now uses versioned alpine tag (16-alpine3.23) not floating
  (16-alpine) — ensures reproducible pulls

## [1.1.6] - 2026-05-25

### Fixed
- v1.1.5 incorrectly removed DropCapability/AddCapability from DB containers.
  Root cause was wrong syntax, not the feature itself.

  Correct quadlet syntax (Podman 5.x):
  - `DropCapability=ALL` — value must be uppercase ALL, passed verbatim to --cap-drop
  - `AddCapability=CHOWN FOWNER SETUID SETGID` — space-separated on one line

  Previous broken form: multiple `AddCapability=CAP` lines with `DropCapability=ALL`
  was generating `--cap-drop all` (lowercase) causing Podman to interpret `all`
  as a container image name.

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
