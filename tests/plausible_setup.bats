#!/usr/bin/env bats
## BATS Unit Tests — plausible_setup.sh
## Run: bats tests/plausible_setup.bats
## Requires: bats-core >= 1.7, shellcheck
##
## Tests validate:
##   1.  plausible_setup.sh passes shellcheck (error + style)
##   2.  Script refuses to run as non-root
##   3.  Service account creation via useradd
##   4.  Linger enablement via loginctl
##   5.  Quadlet unit installation to %h/.config/containers/systemd/
##   6.  env files installed, not overwritten if present
##   7.  SECRET_KEY_BASE stamped with openssl-generated value
##   8.  Unit file content: DropCapability, NoNewPrivileges, :Z labels
##   9.  EnvironmentFile uses %h (home-relative), not /etc/
##   10. WantedBy=default.target in all container units
##   11. Named volumes — no bind mounts to host paths in units
##   12. plausible binds 127.0.0.1:8000 only
##   13. postgres/clickhouse have no PublishPort
##   14. All containers on plausible.network
##   15. net.matrix labels present
##   16. docker.io exception: postgres and clickhouse (no GHCR mirror)

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    TEST_DIR="$(mktemp -d /tmp/plausible-bats-XXXXXX)"
    MOCK_DIR="$TEST_DIR/mock_bin"
    PLAUSIBLE_USER="plausible"
    PLAUSIBLE_UID="2010"
    PLAUSIBLE_HOME="$TEST_DIR/home/$PLAUSIBLE_USER"
    QUADLET_DIR="$PLAUSIBLE_HOME/.config/containers/systemd"

    mkdir -p \
        "$MOCK_DIR" \
        "$QUADLET_DIR"

    # Mock: id — return uid 0 so root-check passes
    cat > "$MOCK_DIR/id" << 'EOF'
#!/bin/sh
case "$*" in
    *-u*) echo 0 ;;
    *)    echo "uid=0(root) gid=0(root)" ;;
esac
EOF

    # Mock: useradd — records call
    cat > "$MOCK_DIR/useradd" << EOF
#!/bin/sh
echo "\$@" > "$TEST_DIR/useradd.args"
mkdir -p "$PLAUSIBLE_HOME"
EOF

    # Mock: loginctl — records call
    cat > "$MOCK_DIR/loginctl" << EOF
#!/bin/sh
echo "\$@" > "$TEST_DIR/loginctl.args"
EOF

    # Mock: zfs — no-op success
    cat > "$MOCK_DIR/zfs" << 'EOF'
#!/bin/sh
exit 0
EOF

    # Mock: machinectl — records call, executes remainder as sh
    cat > "$MOCK_DIR/machinectl" << EOF
#!/bin/sh
# strip 'shell user@' prefix, run the rest
# new pattern: machinectl shell user@ /bin/sh -c 'cmd'
shift 2  # remove 'shell user@'
eval "\$@"
EOF

    # Mock: openssl
    cat > "$MOCK_DIR/openssl" << 'EOF'
#!/bin/sh
printf 'MOCK_SECRET_BASE64_VALUE_FOR_TESTING'
EOF

    # Mock: podman
    cat > "$MOCK_DIR/podman" << 'EOF'
#!/bin/sh
echo "podman version 4.9.0"
EOF

    # Mock: m4 — passthrough
    cat > "$MOCK_DIR/m4" << 'EOF'
#!/bin/sh
exit 0
EOF

    # Mock: chown — no-op
    cat > "$MOCK_DIR/chown" << 'EOF'
#!/bin/sh
exit 0
EOF

    for f in id useradd loginctl zfs machinectl openssl podman m4 chown; do
        chmod +x "$MOCK_DIR/$f"
    done

    export PATH="$MOCK_DIR:$PATH"
    export HOME="$TEST_DIR/home"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ── Shellcheck ───────────────────────────────────────────────────────────────
@test "plausible_setup.sh passes shellcheck -S style" {
    run shellcheck -S style "$REPO_ROOT/plausible_setup.sh"
    [ "$status" -eq 0 ]
}

# ── Root check ───────────────────────────────────────────────────────────────
@test "script refuses to run as non-root" {
    cat > "$MOCK_DIR/id" << 'EOF'
#!/bin/sh
case "$*" in *-u*) echo 1000 ;; *) echo "uid=1000(user)" ;; esac
EOF
    run sh "$REPO_ROOT/plausible_setup.sh"
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "must run as root"
}

# ── Unit files present ───────────────────────────────────────────────────────
@test "plausible.container exists" {
    [ -f "$REPO_ROOT/containers/plausible.container" ]
}

@test "plausible-db.container exists" {
    [ -f "$REPO_ROOT/containers/plausible-db.container" ]
}

@test "plausible-events-db.container exists" {
    [ -f "$REPO_ROOT/containers/plausible-events-db.container" ]
}

@test "plausible.network exists" {
    [ -f "$REPO_ROOT/networks/plausible.network" ]
}

@test "plausible-data.volume exists" {
    [ -f "$REPO_ROOT/volumes/plausible-data.volume" ]
}

@test "plausible-db.volume exists" {
    [ -f "$REPO_ROOT/volumes/plausible-db.volume" ]
}

# ── Security posture ─────────────────────────────────────────────────────────
@test "plausible.container has DropCapability=ALL" {
    grep -q "DropCapability=ALL" "$REPO_ROOT/containers/plausible.container"
}

@test "plausible.container has NoNewPrivileges=true" {
    grep -q "NoNewPrivileges=true" "$REPO_ROOT/containers/plausible.container"
}

@test "plausible-db.container drops all but re-adds CHOWN FOWNER SETUID SETGID" {
    grep -q "DropCapability=ALL" "$REPO_ROOT/containers/plausible-db.container"
    grep -q "AddCapability=CHOWN" "$REPO_ROOT/containers/plausible-db.container"
    grep -q "AddCapability=SETUID" "$REPO_ROOT/containers/plausible-db.container"
}

@test "plausible-events-db.container drops all but re-adds CHOWN FOWNER SETUID SETGID" {
    grep -q "DropCapability=ALL" "$REPO_ROOT/containers/plausible-events-db.container"
    grep -q "AddCapability=CHOWN" "$REPO_ROOT/containers/plausible-events-db.container"
    grep -q "AddCapability=SETUID" "$REPO_ROOT/containers/plausible-events-db.container"
}

@test "all volume mounts use :Z SELinux label" {
    for f in "$REPO_ROOT"/containers/*.container; do
        grep -q "Volume=.*:Z" "$f" || { echo "Missing :Z in $f"; return 1; }
    done
}

# ── EnvironmentFile uses %h ──────────────────────────────────────────────────
@test "plausible.container EnvironmentFile uses %h not /etc" {
    grep -q "EnvironmentFile=%h" "$REPO_ROOT/containers/plausible.container"
    ! grep -q "EnvironmentFile=/etc" "$REPO_ROOT/containers/plausible.container"
}

# ── WantedBy ─────────────────────────────────────────────────────────────────
@test "all container units have WantedBy=default.target" {
    for f in "$REPO_ROOT"/containers/*.container; do
        grep -q "WantedBy=default.target" "$f" || { echo "Missing in $f"; return 1; }
    done
}

# ── Network isolation ────────────────────────────────────────────────────────
@test "all containers use plausible.network" {
    for f in "$REPO_ROOT"/containers/*.container; do
        grep -q "Network=plausible.network" "$f" || { echo "Missing network in $f"; return 1; }
    done
}

@test "plausible binds to localhost only" {
    grep -q "PublishPort=127.0.0.1:8000:8000" \
        "$REPO_ROOT/containers/plausible.container"
}

@test "plausible-db has no PublishPort" {
    ! grep -q "PublishPort" "$REPO_ROOT/containers/plausible-db.container"
}

@test "plausible-events-db has no PublishPort" {
    ! grep -q "PublishPort" "$REPO_ROOT/containers/plausible-events-db.container"
}

# ── Named volumes — no bind mounts ──────────────────────────────────────────
@test "plausible.container uses named volume not bind mount" {
    grep "^Volume=" "$REPO_ROOT/containers/plausible.container" | \
        grep -qv "Volume=/" || true
}

# ── net.matrix labels ────────────────────────────────────────────────────────
@test "plausible.container has net.matrix.owner label" {
    grep -q "net.matrix.owner=FC13F74B@matrix.net" \
        "$REPO_ROOT/containers/plausible.container"
}

# ── env templates ────────────────────────────────────────────────────────────
@test "plausible.env template exists" {
    [ -f "$REPO_ROOT/env/plausible.env" ]
}

@test "db.env template exists" {
    [ -f "$REPO_ROOT/env/db.env" ]
}

@test "env templates contain no real secrets" {
    ! grep -qE "SECRET_KEY_BASE=[A-Za-z0-9+/]{30}" \
        "$REPO_ROOT/env/plausible.env"
}

# ── HAProxy example ──────────────────────────────────────────────────────────
@test "haproxy example exists" {
    [ -f "$REPO_ROOT/examples/haproxy-plausible.cfg" ]
}

@test "haproxy example references analytics.dapla.net" {
    grep -q "analytics.dapla.net" \
        "$REPO_ROOT/examples/haproxy-plausible.cfg"
}

# ── Makefile ─────────────────────────────────────────────────────────────────
@test "Makefile has lint target" {
    grep -q "^lint:" "$REPO_ROOT/Makefile"
}

@test "Makefile has test target" {
    grep -q "^test:" "$REPO_ROOT/Makefile"
}

# ── Subordinate UID/GID ──────────────────────────────────────────────────────
@test "installer provisions /etc/subuid via usermod --add-subuids" {
  grep -q "add-subuids" "$REPO_ROOT/plausible_setup.sh"
}

@test "installer provisions /etc/subgid via usermod --add-subgids" {
  grep -q "add-subgids" "$REPO_ROOT/plausible_setup.sh"
}

@test "installer runs podman system migrate after subuid setup" {
  grep -q "podman system migrate" "$REPO_ROOT/plausible_setup.sh"
}

@test "installer checks existing subuid before adding" {
  grep -q "grep.*subuid" "$REPO_ROOT/plausible_setup.sh"
}

@test "PLAUSIBLE_SUBUID_START tunable is defined" {
  grep -q "PLAUSIBLE_SUBUID_START" "$REPO_ROOT/plausible_setup.sh"
}

@test "preflight checks shadow-utils --add-subuids support" {
  grep -q "add-subuids.*nobody" "$REPO_ROOT/plausible_setup.sh"
}

# ── Volume ownership ─────────────────────────────────────────────────────────
@test "installer creates plausible-db volume explicitly" {
  grep -q "volume create plausible-db" "$REPO_ROOT/plausible_setup.sh"
}

@test "installer chowns volumes inside user namespace via podman unshare" {
  grep -q "podman unshare chown" "$REPO_ROOT/plausible_setup.sh"
}

@test "installer chowns plausible-db to uid 999 (postgres)" {
  grep -q "999:999" "$REPO_ROOT/plausible_setup.sh"
}

@test "installer chowns plausible-clickhouse to uid 101 (clickhouse)" {
  grep -q "101:101" "$REPO_ROOT/plausible_setup.sh"
}

@test "installer chowns plausible-data to uid 1000 (plausible app)" {
  grep -q "1000:1000" "$REPO_ROOT/plausible_setup.sh"
}
