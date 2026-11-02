#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
root=$PWD
archive=$(./scripts/package.sh)
(
    cd "$root/binaries"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -c SHA256SUMS.txt
    else
        shasum -a 256 -c SHA256SUMS.txt
    fi
)
work=$(mktemp -d "$root/.work/consumer.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/project/src" "$work/project/vendor"
unzip -q "$archive" -d "$work/project/vendor"
cp tests/consumer/main.odin "$work/project/src/"
# Run from the consumer root with no library collection flag or repository helper.
cd "$work/project"
odin run src -vet "-out:$work/consumer"
odin check src -vet -target:js_wasm32 -define:RAYLIB_WASM_LIB=env.o -no-entry-point
