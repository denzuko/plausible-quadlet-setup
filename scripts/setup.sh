#!/bin/sh
# setup.sh — thin wrapper; prefer `make install`
exec make -C "$(dirname "$0")/.." install "$@"
