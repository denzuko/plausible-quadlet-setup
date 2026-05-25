# Changelog

All notable changes to plausible-quadlet-setup.

## [1.0.1] - 2026-05-25

### Fixed
- `setup.sh` brace expansion: `mkdir -p {data,db,...}` is bash-only, not POSIX sh.
  Replaced with individual `mkdir -p` calls in Makefile.
- `setup.sh` replaced with thin `make install` wrapper.

### Added
- `Makefile` at repo root: `install`, `uninstall`, `start`, `stop`, `status`, `logs`, `test`
- Supports `make -C $NS install` install pattern
- Bats tests for Makefile targets and POSIX sh compliance

## [1.0.0] - 2026-05-25

### Added
- Initial release — see 1.0.0 tag for full list
