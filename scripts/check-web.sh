#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .work
work=$(mktemp -d "$PWD/.work/web-check.XXXXXX")
trap 'rm -rf "$work"' EXIT
# Inspection exports are restricted to this temporary debug artifact.
UI_WEB_SMOKE=true WEB_OUTPUT_DIR="$work/web" ./scripts/build-example.sh web
"${NODE:-node}" tools/check-web.mjs "$work/web"
