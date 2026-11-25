#!/bin/sh
set -eu
# Optional arguments are forwarded directly to each Odin compiler invocation.
project=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
if [ "${PROJECT_ROOT:-}" != "$project" ] || [ -z "${PROJECT_NIX_ENVIRONMENT:-}" ]; then
    exec "$project/scripts/dev" "$project/scripts/check-vendored.sh" "$@"
fi
cd "$project"
root=$PWD
archive=$(./scripts/package.sh)
(
    cd "$root/.work/package"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -c SHA256SUMS.txt
    else
        shasum -a 256 -c SHA256SUMS.txt
    fi
)
mkdir -p "$root/.work/build"
work=$(mktemp -d "$root/.work/build/consumer.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/project/src" "$work/project/vendor"
unzip -q "$archive" -d "$work/project/vendor"
cp tests/consumer/main.odin "$work/project/src/"
# Run from the consumer root with no library collection flag or repository helper.
cd "$work/project"
vet_flags='-vet -vet-tabs -vet-using-param -vet-nil-deref -vet-uninitialized -vet-atomic-access -strict-style -warnings-as-errors -vet-unused-procedures -vet-packages:consumer -strict-style-packages:consumer'
"${ODIN:-odin}" run src $vet_flags "-out:$work/consumer" "$@"
"${ODIN:-odin}" check src $vet_flags -target:js_wasm32 -define:RAYLIB_WASM_LIB=env.o -no-entry-point "$@"
