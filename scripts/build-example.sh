#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
ODIN=$(./scripts/odin.sh --compiler)
export ODIN
mkdir -p binaries .work
case "${1:-desktop}" in
    desktop)
        exec ./scripts/odin.sh build examples/showcase -vet -debug -out:binaries/showcase
        ;;
    web)
        . ./scripts/web-toolchain.sh
        web_output=${WEB_OUTPUT_DIR:-"$PWD/binaries/web"}
        work=$(mktemp -d "$PWD/.work/showcase.XXXXXX")
        trap 'rm -rf "$work"' EXIT
        mkdir -p "$work/web"
        ./scripts/odin.sh build examples/showcase -vet -debug -target:js_wasm32 -build-mode:obj \
            -webkit-switch-workaround -define:RAYLIB_WASM_LIB=env.o "-define:UI_WEB_SMOKE=${UI_WEB_SMOKE:-false}" "-out:$work/showcase.o"
        "$EMCC" "$work/showcase.o" "$RAYLIB_WEB_LIB" -o "$work/web/showcase.js" -O1 -g \
            -sUSE_GLFW=3 -sSTACK_SIZE=2097152 -sINITIAL_MEMORY=33554432 \
            -sALLOW_MEMORY_GROWTH=1 -sASSERTIONS=1 -sENVIRONMENT=web \
            --js-library examples/showcase/odin-library.js
        cp "$("$ODIN" root)/core/sys/wasm/js/odin.js" "$work/web/odin.js"
        cp examples/showcase/index.html "$work/web/index.html"
        cp examples/showcase/assets/OFL.txt "$work/web/FONT-LICENSE.txt"
        mkdir -p "$web_output"
        cp "$work/web/"* "$web_output/"
        ;;
    *) echo 'Usage: scripts/build-example.sh [desktop|web]' >&2; exit 1 ;;
esac
