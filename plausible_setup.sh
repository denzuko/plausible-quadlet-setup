#!/bin/sh
# plausible_setup.sh — Plausible CE rootless quadlet installer v1.1.0
#
# Intended usage:
#   curl -fsSL https://denzuko.github.io/plausible-quadlet-setup/plausible_setup.sh | doas sh
#   curl -fsSL https://denzuko.github.io/plausible-quadlet-setup/plausible_setup.sh | doas env PLAUSIBLE_USER=analytics sh
#
# All tunables are environment variables. Defaults are chosen for the
# dapla.net stack; override anything at runtime — no flags, no prompts.
#
# Uninstall:
#   PLAUSIBLE_UNINSTALL=1 sh plausible_setup.sh
#
# Requirements:
#   openssl, zfs/zpool, podman >= 4.4, systemd >= 252,
#   machinectl, useradd, loginctl, m4

set -eu

# ---------------------------------------------------------------------------
# SECTION 1: Tunables
# ---------------------------------------------------------------------------
PLAUSIBLE_USER="${PLAUSIBLE_USER:-plausible}"
PLAUSIBLE_UID="${PLAUSIBLE_UID:-2010}"
PLAUSIBLE_VERSION="${PLAUSIBLE_VERSION:-v2.1.4}"

ZFS_POOL="${ZFS_POOL:-storage}"

DS_CONTAINER="${ZFS_POOL}/containers/plausible"
DS_USER="${ZFS_POOL}/users/plausible"
MNT_CONTAINER="/srv/plausible"
MNT_USER="/var/lib/plausible"

QUADLET_DIR=""   # computed after user creation

PLAUSIBLE_UNINSTALL="${PLAUSIBLE_UNINSTALL:-0}"

# ---------------------------------------------------------------------------
# SECTION 2: Utilities
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

die() { printf 'FATAL: %s\n' "$*" >&2; exit 1; }

render() {
    _macro="$1"; shift
    printf '%s()\n' "$_macro" | m4 \
        -D PLAUSIBLE_USER="$PLAUSIBLE_USER" \
        -D PLAUSIBLE_UID="$PLAUSIBLE_UID" \
        -D PLAUSIBLE_VERSION="$PLAUSIBLE_VERSION" \
        -D ZFS_POOL="$ZFS_POOL" \
        -D DS_CONTAINER="$DS_CONTAINER" \
        -D DS_USER="$DS_USER" \
        -D MNT_CONTAINER="$MNT_CONTAINER" \
        -D MNT_USER="$MNT_USER" \
        -D QUADLET_DIR="${QUADLET_DIR:-pending}" \
        -D PLAUSIBLE_RUNTIME_UID="$(id -u "$PLAUSIBLE_USER" 2>/dev/null || echo "$PLAUSIBLE_UID")" \
        -D PODMAN_VER="$(podman --version 2>/dev/null || echo unknown)" \
        "$@" \
        "$SCRIPT_DIR/share/summary.m4" -
}

# ---------------------------------------------------------------------------
# SECTION 3: Preflight
# ---------------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "must run as root"
command -v podman  >/dev/null || die "podman not found"
command -v zfs     >/dev/null || die "zfs not found"
command -v m4      >/dev/null || die "m4 not found"
command -v openssl >/dev/null || die "openssl not found"

render _preflight

# ---------------------------------------------------------------------------
# SECTION 4: Uninstall
# ---------------------------------------------------------------------------
if [ "$PLAUSIBLE_UNINSTALL" = "1" ]; then
    QUADLET_DIR="$(eval echo "~${PLAUSIBLE_USER}/.config/containers/systemd")"
    machinectl shell "${PLAUSIBLE_USER}@" /bin/sh -c 'systemctl --user stop plausible plausible-db plausible-events-db' 2>/dev/null || true
    rm -f \
        "${QUADLET_DIR}/plausible.container" \
        "${QUADLET_DIR}/plausible-db.container" \
        "${QUADLET_DIR}/plausible-events-db.container" \
        "${QUADLET_DIR}/plausible.network" \
        "${QUADLET_DIR}/plausible-data.volume" \
        "${QUADLET_DIR}/plausible-db.volume" \
        "${QUADLET_DIR}/plausible-clickhouse.volume" \
        "${QUADLET_DIR}/plausible-clickhouse-logs.volume"
    machinectl shell "${PLAUSIBLE_USER}@" /bin/sh -c 'systemctl --user daemon-reload' 2>/dev/null || true
    printf '==> Uninstall complete. ZFS datasets retained.\n'
    printf '    Remove manually: zfs destroy -r %s\n' "$DS_CONTAINER"
    exit 0
fi

# ---------------------------------------------------------------------------
# SECTION 5: ZFS datasets
# ---------------------------------------------------------------------------
printf '==> ZFS datasets\n'
zfs create -o mountpoint="$MNT_CONTAINER" \
    -o compression=lz4 -o atime=off \
    "$DS_CONTAINER" 2>/dev/null || true
zfs set "plausible:version=${PLAUSIBLE_VERSION}" "$DS_CONTAINER" 2>/dev/null || true
zfs snapshot "${DS_CONTAINER}@install-${PLAUSIBLE_VERSION}-$(date +%Y%m%d)" 2>/dev/null || true

zfs create -o mountpoint="$MNT_USER" \
    -o compression=lz4 -o atime=off \
    "$DS_USER" 2>/dev/null || true

# ---------------------------------------------------------------------------
# SECTION 6: System user
# ---------------------------------------------------------------------------
printf '==> System user\n'
id "$PLAUSIBLE_USER" >/dev/null 2>&1 || \
    useradd --no-create-home \
        --uid "$PLAUSIBLE_UID" \
        --home-dir "$MNT_USER" \
        --shell /sbin/nologin \
        "$PLAUSIBLE_USER"

chown -R "${PLAUSIBLE_USER}:${PLAUSIBLE_USER}" "$MNT_CONTAINER" "$MNT_USER"
loginctl enable-linger "$PLAUSIBLE_USER"

QUADLET_DIR="$(eval echo "~${PLAUSIBLE_USER}/.config/containers/systemd")"
mkdir -p "$QUADLET_DIR"

# ---------------------------------------------------------------------------
# SECTION 7: Quadlet units
# ---------------------------------------------------------------------------
printf '==> Quadlet units\n'
for f in \
    containers/plausible.container \
    containers/plausible-db.container \
    containers/plausible-events-db.container \
    networks/plausible.network \
    volumes/plausible-data.volume \
    volumes/plausible-db.volume \
    volumes/plausible-clickhouse.volume \
    volumes/plausible-clickhouse-logs.volume; do
    install -m 0644 "${SCRIPT_DIR}/${f}" "${QUADLET_DIR}/$(basename "$f")"
done
chown -R "${PLAUSIBLE_USER}:${PLAUSIBLE_USER}" "$QUADLET_DIR"

# ---------------------------------------------------------------------------
# SECTION 8: Environment files
# ---------------------------------------------------------------------------
printf '==> Environment\n'
SECRET=$(openssl rand -base64 64 | tr -d '\n')

if [ ! -f "${QUADLET_DIR}/plausible.env" ]; then
    install -m 0640 "${SCRIPT_DIR}/env/plausible.env" "${QUADLET_DIR}/plausible.env"
    # Stamp generated secret
    sed -i "s|SECRET_KEY_BASE=CHANGE_ME|SECRET_KEY_BASE=${SECRET}|" \
        "${QUADLET_DIR}/plausible.env"
    printf '    Created plausible.env — set DATABASE_URL password and SMTP before starting\n'
fi

if [ ! -f "${QUADLET_DIR}/db.env" ]; then
    install -m 0640 "${SCRIPT_DIR}/env/db.env" "${QUADLET_DIR}/db.env"
    printf '    Created db.env — set POSTGRES_PASSWORD before starting\n'
fi

chown "${PLAUSIBLE_USER}:${PLAUSIBLE_USER}" \
    "${QUADLET_DIR}/plausible.env" \
    "${QUADLET_DIR}/db.env"

# ---------------------------------------------------------------------------
# SECTION 9: Reload systemd
# ---------------------------------------------------------------------------
printf '==> systemd daemon-reload\n'
machinectl shell "${PLAUSIBLE_USER}@" /bin/sh -c 'systemctl --user daemon-reload'

# ---------------------------------------------------------------------------
# SECTION 10: Summary
# ---------------------------------------------------------------------------
render _header
render _endpoints
render _ops

printf '\nNext:\n'
printf '  1. Edit %s/plausible.env — set DATABASE_URL password + SMTP\n' "$QUADLET_DIR"
printf '  2. Edit %s/db.env — set POSTGRES_PASSWORD\n' "$QUADLET_DIR"
printf '  3. Add examples/haproxy-plausible.cfg to HAProxy config\n'
printf '  4. machinectl shell %s@ /bin/sh -c \"systemctl --user start plausible\"\n' "$PLAUSIBLE_USER"
