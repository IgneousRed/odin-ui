#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .work
vet_flags='-vet -vet-tabs -vet-using-param -vet-nil-deref -vet-uninitialized -vet-atomic-access -strict-style -warnings-as-errors'
owned_vet="$vet_flags -vet-packages:layout,text,input,raylib_ui,showcase,layout_tests,text_tests,input_tests,raylib_tests,draw_tests,consumer -strict-style-packages:layout,text,input,raylib_ui,showcase,layout_tests,text_tests,input_tests,raylib_tests,draw_tests,consumer"
work=$(mktemp -d "$PWD/.work/check.XXXXXX")
trap 'rm -rf "$work"' EXIT
for script in scripts/*.sh; do
    sh -n "$script"
done
allium check spec/ui-layout.allium
for package in layout text input raylib; do
    ./scripts/odin.sh check "src/$package" -no-entry-point $owned_vet
    ./scripts/odin.sh test "tests/${package}_tests" $owned_vet "-out:$work/$package-tests"
done
./scripts/odin.sh check examples/showcase $owned_vet
./scripts/odin.sh check examples/showcase $vet_flags -vet-unused-procedures -vet-packages:showcase
./scripts/odin.sh check examples/showcase -target:js_wasm32 -define:RAYLIB_WASM_LIB=env.o -no-entry-point $owned_vet
./scripts/odin.sh check examples/showcase -target:js_wasm32 -define:RAYLIB_WASM_LIB=env.o -no-entry-point $vet_flags -vet-unused-procedures -vet-packages:showcase
for package in layout text input; do
    ./scripts/odin.sh check "src/$package" -target:js_wasm32 -no-entry-point $owned_vet
done
# Drawing captures use the real raylib measurements without a window or GPU.
# Single-threaded tests also serialize raylib's process-global line spacing.
case "$(uname -s)" in
    Darwin) draw_flags='-define:RAYLIB_SHARED=true' ;;
    Linux) draw_flags='-extra-linker-flags:-Wl,--wrap=BeginScissorMode,--wrap=EndScissorMode,--wrap=DrawRectangleRec,--wrap=DrawRectangleRounded,--wrap=DrawRectangleRoundedLinesEx,--wrap=DrawTextCodepoints' ;;
    *) echo 'Drawing capture checks support macOS and Linux.' >&2; exit 2 ;;
esac
./scripts/odin.sh test tests/draw_tests $owned_vet "$draw_flags" -define:ODIN_TEST_THREADS=1 "-out:$work/draw-tests"
./scripts/check-vendored.sh
# Compiler checks (including the copied consumer) must pass before shared lint.
python3 tools/run-odin-lint.py odin-lint.lock.json \
    --root . --source-root src --collection odin_ui=src src examples tests
