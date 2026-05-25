SHELL   := /bin/sh
SCRIPT  := plausible_setup.sh

UNITS := \
	containers/plausible.container \
	containers/plausible-db.container \
	containers/plausible-events-db.container \
	networks/plausible.network \
	volumes/plausible-data.volume \
	volumes/plausible-db.volume \
	volumes/plausible-clickhouse.volume \
	volumes/plausible-clickhouse-logs.volume

.PHONY: all lint test install uninstall status logs help

all: help

help:
	@printf 'plausible-quadlet-setup\n\n'
	@printf '  make lint       shellcheck the installer\n'
	@printf '  make test       run bats test suite\n'
	@printf '  make install    deploy to this host (requires root)\n'
	@printf '  make uninstall  remove quadlets (ZFS datasets retained)\n'
	@printf '  make status     show service status\n'
	@printf '  make logs       tail Plausible logs\n'

lint:
	shellcheck -S style $(SCRIPT)

test:
	bats tests/plausible_setup.bats

install:
	sh $(SCRIPT)

uninstall:
	PLAUSIBLE_UNINSTALL=1 sh $(SCRIPT)

status:
	machinectl shell plausible@ -- \
	  systemctl --user status plausible plausible-db plausible-events-db || true

logs:
	machinectl shell plausible@ -- \
	  journalctl --user -u plausible.service -f
