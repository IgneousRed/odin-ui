#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .work
work=$(mktemp -d "$PWD/.work/check.XXXXXX")
trap 'rm -rf "$work"' EXIT
allium check spec/ui-layout.allium
for package in layout text input raylib; do
    ./scripts/odin.sh check "src/$package" -no-entry-point -vet
    ./scripts/odin.sh test "tests/$package" -vet "-out:$work/$package-tests"
done
./scripts/odin.sh check examples/showcase -vet
./scripts/odin.sh check examples/showcase -target:js_wasm32 -define:RAYLIB_WASM_LIB=env.o -no-entry-point -vet
for package in layout text input; do
    ./scripts/odin.sh check "src/$package" -target:js_wasm32 -no-entry-point -vet
done
