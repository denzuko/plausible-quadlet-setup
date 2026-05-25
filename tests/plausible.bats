#!/usr/bin/env bats
# tests/plausible.bats — BDD tests for plausible-quadlet-setup
# Run: bats tests/plausible.bats

setup() {
  QUADLET_DIR="$HOME/.config/containers/systemd"
}

# ── Quadlet files present ────────────────────────────────────────
@test "plausible.container exists" {
  [ -f "quadlets/plausible.container" ]
}

@test "plausible-db.container exists" {
  [ -f "quadlets/plausible-db.container" ]
}

@test "plausible-events-db.container exists" {
  [ -f "quadlets/plausible-events-db.container" ]
}

@test "plausible.network exists" {
  [ -f "quadlets/plausible.network" ]
}

# ── net.matrix labels present ────────────────────────────────────
@test "plausible.container has net.matrix.owner label" {
  grep -q "net.matrix.owner=FC13F74B@matrix.net" quadlets/plausible.container
}

@test "plausible.container has net.matrix.project label" {
  grep -q "net.matrix.project=plausible-quadlet-setup" quadlets/plausible.container
}

# ── Network isolation ────────────────────────────────────────────
@test "plausible.container uses plausible network" {
  grep -q "Network=plausible.network" quadlets/plausible.container
}

@test "plausible-db.container uses plausible network" {
  grep -q "Network=plausible.network" quadlets/plausible-db.container
}

@test "plausible-events-db.container uses plausible network" {
  grep -q "Network=plausible.network" quadlets/plausible-events-db.container
}

# ── Port binding — localhost only ────────────────────────────────
@test "plausible binds to localhost only" {
  grep -q "PublishPort=127.0.0.1:8000:8000" quadlets/plausible.container
}

@test "plausible-db does not expose ports externally" {
  ! grep -q "PublishPort" quadlets/plausible-db.container
}

@test "plausible-events-db does not expose ports externally" {
  ! grep -q "PublishPort" quadlets/plausible-events-db.container
}

# ── ZFS volume paths ────────────────────────────────────────────
@test "plausible uses /srv/plausible/data volume" {
  grep -q "Volume=/srv/plausible/data" quadlets/plausible.container
}

@test "plausible-db uses /srv/plausible/db volume" {
  grep -q "Volume=/srv/plausible/db" quadlets/plausible-db.container
}

# ── Restart policy ──────────────────────────────────────────────
@test "plausible has Restart=always" {
  grep -q "Restart=always" quadlets/plausible.container
}

# ── Config examples present ─────────────────────────────────────
@test "plausible.env.example exists" {
  [ -f "config/plausible.env.example" ]
}

@test "db.env.example exists" {
  [ -f "config/db.env.example" ]
}

@test "haproxy config snippet exists" {
  [ -f "config/haproxy-analytics.cfg" ]
}

@test "haproxy config uses analytics.dapla.net" {
  grep -q "analytics.dapla.net" config/haproxy-analytics.cfg
}

@test "env example has BASE_URL for analytics.dapla.net" {
  grep -q "analytics.dapla.net" config/plausible.env.example
}

@test "env example does not contain real secrets" {
  ! grep -qE "SECRET_KEY_BASE=[a-zA-Z0-9+/]{40}" config/plausible.env.example
}

@test "setup.sh is executable" {
  [ -x "scripts/setup.sh" ]
}
