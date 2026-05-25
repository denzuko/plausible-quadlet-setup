# Changelog

All notable changes to plausible-quadlet-setup.

## [1.0.0] - 2026-05-25

### Added
- `plausible.container` — Plausible CE v2.1.4 rootless Podman quadlet
- `plausible-db.container` — PostgreSQL 16-alpine quadlet
- `plausible-events-db.container` — ClickHouse 24.3 quadlet
- `plausible.network` — isolated bridge network
- `config/plausible.env.example` — environment template with all required vars
- `config/db.env.example` — PostgreSQL credentials template
- `config/haproxy-analytics.cfg` — HAProxy reverse proxy snippet for analytics.dapla.net
- `scripts/setup.sh` — ZFS dataset + system user + quadlet install script
- `tests/plausible.bats` — BDD test suite (29 assertions)
- net.matrix label schema throughout (owner FC13F74B@matrix.net)
- Port binding: Plausible on 127.0.0.1:8000 only (not externally exposed)
- ZFS volume paths: storage/containers/plausible → /srv/plausible
