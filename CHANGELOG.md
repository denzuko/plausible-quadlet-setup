# Changelog

All notable changes to plausible-quadlet-setup.

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
