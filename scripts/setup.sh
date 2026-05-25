#!/bin/sh
# setup.sh — provision ZFS datasets, system user, and install quadlets
# Run as root on the target host before starting services
set -e

PLAUSIBLE_USER=plausible
ZFS_POOL=storage

# ZFS datasets
zfs create -o mountpoint=/srv/plausible ${ZFS_POOL}/containers/plausible
zfs create -o mountpoint=/var/lib/plausible ${ZFS_POOL}/users/plausible

# Subdirectories
mkdir -p /srv/plausible/{data,db,clickhouse,clickhouse-logs,config}

# System user
useradd -r -d /var/lib/plausible -s /sbin/nologin ${PLAUSIBLE_USER}
chown -R ${PLAUSIBLE_USER}:${PLAUSIBLE_USER} \
  /srv/plausible \
  /var/lib/plausible

# Enable linger so user services start on boot
loginctl enable-linger ${PLAUSIBLE_USER}

# Install quadlets to user systemd directory
QUADLET_DIR=$(eval echo "~${PLAUSIBLE_USER}/.config/containers/systemd")
mkdir -p "${QUADLET_DIR}"
cp quadlets/*.container quadlets/*.network "${QUADLET_DIR}/"
chown -R ${PLAUSIBLE_USER}:${PLAUSIBLE_USER} "${QUADLET_DIR}"

echo ""
echo "Next steps:"
echo "  1. Copy config/plausible.env.example → /srv/plausible/config/plausible.env"
echo "  2. Copy config/db.env.example        → /srv/plausible/config/db.env"
echo "  3. Fill in SECRET_KEY_BASE, passwords, SMTP"
echo "  4. Add haproxy-analytics.cfg snippet to HAProxy config"
echo "  5. su -s /bin/sh ${PLAUSIBLE_USER} -c 'systemctl --user daemon-reload'"
echo "  6. su -s /bin/sh ${PLAUSIBLE_USER} -c 'systemctl --user start plausible'"
