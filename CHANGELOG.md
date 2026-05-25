# Changelog

All notable changes to plausible-quadlet-setup.

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
