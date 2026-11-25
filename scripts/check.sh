#!/bin/sh
set -eu
# Optional arguments are forwarded directly to each Odin compiler invocation.
project=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
if [ "${PROJECT_ROOT:-}" != "$project" ] || [ -z "${PROJECT_NIX_ENVIRONMENT:-}" ]; then
    exec "$project/scripts/dev" "$project/scripts/check.sh" "$@"
fi
cd "$project"
ODIN=$(./scripts/odin.sh --compiler)
export ODIN
mkdir -p .work/build
vet_flags='-vet -vet-tabs -vet-using-param -vet-nil-deref -vet-uninitialized -vet-atomic-access -strict-style -warnings-as-errors'
owned_vet="$vet_flags -vet-packages:layout,text,input,raylib_ui,showcase,failure_policy,layout_tests,text_tests,input_tests,raylib_tests,draw_tests,consumer -strict-style-packages:layout,text,input,raylib_ui,showcase,failure_policy,layout_tests,text_tests,input_tests,raylib_tests,draw_tests,consumer"
work=$(mktemp -d "$PWD/.work/build/check.XXXXXX")
trap 'rm -rf "$work"' EXIT
for script in scripts/*.sh; do
    sh -n "$script"
done
python3 -B tools/test_web_toolchain.py
python3 -B tools/test_fuzz_driver.py
python3 -B tools/test_publication.py
python3 -B scripts/test-dev.py
python3 -B tests/test_check_deps.py
"${NODE:-node}" tools/test-web-host.mjs
allium check spec/ui-layout.allium
for package in layout text input raylib; do
    ./scripts/odin.sh check "src/$package" -no-entry-point $owned_vet "$@"
    ./scripts/odin.sh test "tests/${package}_tests" $owned_vet "-out:$work/$package-tests" "$@"
done
./scripts/odin.sh check examples/showcase $owned_vet "$@"
./scripts/odin.sh check examples/showcase $vet_flags -vet-unused-procedures -vet-packages:showcase "$@"
./scripts/odin.sh check examples/showcase -target:js_wasm32 -define:RAYLIB_WASM_LIB=env.o -no-entry-point $owned_vet "$@"
./scripts/odin.sh check examples/showcase -target:js_wasm32 -define:RAYLIB_WASM_LIB=env.o -no-entry-point $vet_flags -vet-unused-procedures -vet-packages:showcase "$@"
./scripts/odin.sh check examples/showcase -target:js_wasm32 -define:RAYLIB_WASM_LIB=env.o -define:UI_WEB_SMOKE=true -no-entry-point $owned_vet "$@"
./scripts/odin.sh check examples/showcase -target:js_wasm32 -define:RAYLIB_WASM_LIB=env.o -define:UI_WEB_SMOKE=true -no-entry-point $vet_flags -vet-unused-procedures -vet-packages:showcase "$@"
for package in layout text input; do
    ./scripts/odin.sh check "src/$package" -target:js_wasm32 -no-entry-point $owned_vet "$@"
done
# The host-owned failure-policy example is portable and runs its documented cases.
./scripts/odin.sh run examples/failure_policy $owned_vet "-out:$work/failure-policy" "$@"
./scripts/odin.sh check examples/failure_policy $vet_flags -vet-unused-procedures -vet-packages:failure_policy -strict-style-packages:failure_policy "$@"
./scripts/odin.sh check examples/failure_policy -target:js_wasm32 -no-entry-point $owned_vet "$@"
./scripts/odin.sh check examples/failure_policy -target:js_wasm32 -no-entry-point $vet_flags -vet-unused-procedures -vet-packages:failure_policy -strict-style-packages:failure_policy "$@"
# Drawing captures use the real raylib measurements without a window or GPU.
# Single-threaded tests also serialize raylib's process-global line spacing.
case "$(uname -s)" in
    Darwin) draw_flags='-define:RAYLIB_SHARED=true' ;;
    Linux) draw_flags='-extra-linker-flags:-Wl,--wrap=BeginScissorMode,--wrap=EndScissorMode,--wrap=DrawRectangleRec,--wrap=DrawRectangleRounded,--wrap=DrawRectangleRoundedLinesEx,--wrap=DrawTextCodepoints' ;;
    *) echo 'Drawing capture checks support macOS and Linux.' >&2; exit 2 ;;
esac
./scripts/odin.sh test tests/draw_tests $owned_vet "$draw_flags" -define:ODIN_TEST_THREADS=1 "-out:$work/draw-tests" "$@"
# The replay examples use the same seeds/configuration as disposable exploration.
./scripts/odin.sh build examples/showcase $owned_vet "$draw_flags" -define:UI_REPLAY=true "-out:$work/showcase-replay" "$@"
"$work/showcase-replay"
./scripts/odin.sh check examples/showcase $vet_flags "$draw_flags" -define:UI_REPLAY=true -vet-unused-procedures -vet-packages:showcase -strict-style-packages:showcase "$@"
./scripts/odin.sh build examples/failure_policy $owned_vet -define:UI_REPLAY=true "-out:$work/failure-replay" "$@"
"$work/failure-replay"
./scripts/odin.sh check examples/failure_policy $vet_flags -define:UI_REPLAY=true -vet-unused-procedures -vet-packages:failure_policy -strict-style-packages:failure_policy "$@"
python3 -B tools/test_replay.py "$work/showcase-replay" "$work/failure-replay"
./scripts/check-vendored.sh "$@"
# Compiler checks (including the copied consumer) must pass before shared lint.
"$ODIN_LINT_BIN" \
    --root . --source-root src --collection odin_ui=src src examples tests

# Optional runtime dependencies are explicit; the portable check never installs them.
if [ "${CHECK_WEB:-0}" = 1 ]; then
    ./scripts/check-web.sh "$@"
fi
