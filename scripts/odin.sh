#!/bin/sh
set -eu
project=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
if [ "${PROJECT_ROOT:-}" != "$project" ] || [ -z "${PROJECT_NIX_ENVIRONMENT:-}" ]; then
    exec "$project/scripts/dev" "$project/scripts/odin.sh" "$@"
fi
compiler=${ODIN:?The locked environment must supply ODIN}
if [ "${1:-}" = --compiler ]; then
    printf '%s\n' "$compiler"
    exit 0
fi
case "${1:-}" in
    version|root|report) exec "$compiler" "$@" ;;
esac
ui="$project/src"
if [ ! -f "$ui/raylib/raylib.odin" ]; then
    echo "Odin UI missing: $ui (restore the project's versioned source)" >&2
    exit 1
fi
exec "$compiler" "$@" "-collection:odin_ui=$ui"
