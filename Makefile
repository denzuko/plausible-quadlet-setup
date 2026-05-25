# Makefile — plausible-quadlet-setup
# Usage:
#   make install          Install quadlets, ZFS, user, config
#   make uninstall        Stop services, remove quadlets
#   make test             Run bats test suite
#   make status           Show service status
#   make logs             Tail Plausible logs
#
# One-liner install from repo:
#   mdo env NS=$(mktemp -d) REPO="https://github.com/denzuko/plausible-quadlet-setup" PS1="% " sh
#   git clone --depth=1 $REPO $NS && make -C $NS install

SHELL        := /bin/sh
ZFS_POOL     := storage
SERVICE_USER := plausible
QUADLET_DIR  := $(shell eval echo "~$(SERVICE_USER)/.config/containers/systemd")
SRV_ROOT     := /srv/plausible
VAR_LIB      := /var/lib/plausible

.PHONY: all install uninstall test status logs zfs user quadlets config help

all: help

help:
	@echo "plausible-quadlet-setup"
	@echo ""
	@echo "  make install    — provision ZFS, user, quadlets, check config"
	@echo "  make uninstall  — stop services, remove quadlets"
	@echo "  make test       — run bats test suite"
	@echo "  make status     — show systemd service status"
	@echo "  make logs       — tail Plausible container logs"

install: zfs user quadlets config
	@echo ""
	@echo "Installation complete. Next:"
	@echo "  Edit $(SRV_ROOT)/config/plausible.env"
	@echo "  Edit $(SRV_ROOT)/config/db.env"
	@echo "  make start"

zfs:
	@echo "==> ZFS datasets"
	zfs create -o mountpoint=$(SRV_ROOT) $(ZFS_POOL)/containers/plausible || true
	zfs create -o mountpoint=$(VAR_LIB) $(ZFS_POOL)/users/plausible || true
	mkdir -p $(SRV_ROOT)/data
	mkdir -p $(SRV_ROOT)/db
	mkdir -p $(SRV_ROOT)/clickhouse
	mkdir -p $(SRV_ROOT)/clickhouse-logs
	mkdir -p $(SRV_ROOT)/config

user:
	@echo "==> System user"
	id $(SERVICE_USER) >/dev/null 2>&1 || \
	  useradd -r -d $(VAR_LIB) -s /sbin/nologin $(SERVICE_USER)
	chown -R $(SERVICE_USER):$(SERVICE_USER) $(SRV_ROOT) $(VAR_LIB)
	loginctl enable-linger $(SERVICE_USER)

quadlets:
	@echo "==> Quadlet units"
	mkdir -p $(QUADLET_DIR)
	cp quadlets/*.container quadlets/*.network $(QUADLET_DIR)/
	chown -R $(SERVICE_USER):$(SERVICE_USER) $(QUADLET_DIR)
	su -s /bin/sh $(SERVICE_USER) -c 'systemctl --user daemon-reload'

config:
	@echo "==> Config templates"
	@test -f $(SRV_ROOT)/config/plausible.env || \
	  (cp config/plausible.env.example $(SRV_ROOT)/config/plausible.env && \
	   echo "  Created $(SRV_ROOT)/config/plausible.env — fill in secrets before starting")
	@test -f $(SRV_ROOT)/config/db.env || \
	  (cp config/db.env.example $(SRV_ROOT)/config/db.env && \
	   echo "  Created $(SRV_ROOT)/config/db.env — fill in password before starting")

start:
	su -s /bin/sh $(SERVICE_USER) -c 'systemctl --user start plausible'

stop:
	su -s /bin/sh $(SERVICE_USER) -c 'systemctl --user stop plausible plausible-db plausible-events-db' || true

status:
	su -s /bin/sh $(SERVICE_USER) -c \
	  'systemctl --user status plausible plausible-db plausible-events-db' || true

logs:
	su -s /bin/sh $(SERVICE_USER) -c \
	  'journalctl --user -u plausible -f'

test:
	bats tests/plausible.bats

uninstall: stop
	@echo "==> Removing quadlets"
	rm -f $(QUADLET_DIR)/plausible*.container
	rm -f $(QUADLET_DIR)/plausible.network
	su -s /bin/sh $(SERVICE_USER) -c 'systemctl --user daemon-reload'
	@echo "==> ZFS datasets retained — remove manually if needed:"
	@echo "    zfs destroy $(ZFS_POOL)/containers/plausible"
	@echo "    zfs destroy $(ZFS_POOL)/users/plausible"
