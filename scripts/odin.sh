#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
exec "${ODIN:-odin}" "$@" "-collection:odin_ui=$root/src"
