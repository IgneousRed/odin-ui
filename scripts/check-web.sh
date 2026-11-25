#!/bin/sh
set -eu
project=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
if [ "${PROJECT_ROOT:-}" != "$project" ] || [ -z "${PROJECT_NIX_ENVIRONMENT:-}" ]; then
    exec "$project/scripts/dev" "$project/scripts/check-web.sh" "$@"
fi
cd "$project"
mkdir -p .work/build
work=$(mktemp -d "$PWD/.work/build/web-check.XXXXXX")
trap 'rm -rf "$work"' EXIT
# Inspection exports are restricted to this temporary debug artifact.
UI_WEB_SMOKE=true WEB_OUTPUT_DIR="$work/web" ./scripts/build-example.sh web "$@"
"${NODE:-node}" tools/check-web.mjs "$work/web"
