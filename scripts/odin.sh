#!/bin/sh
set -eu
project=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
compiler=${ODIN:-}
if [ -z "$compiler" ]; then
    if command -v brew >/dev/null 2>&1 && [ -x "$(brew --prefix odin)/bin/odin" ]; then
        compiler="$(brew --prefix odin)/bin/odin"
    else
        compiler=odin
    fi
fi
compiler=$(python3 - "$compiler" <<'PY'
from pathlib import Path
import shutil
import sys
compiler = shutil.which(sys.argv[1])
if compiler is None:
    raise SystemExit(f'Odin compiler not found: {sys.argv[1]}')
print(Path(compiler).resolve())
PY
)
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
