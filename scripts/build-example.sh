#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p binaries .work
case "${1:-desktop}" in
    desktop)
        exec ./scripts/odin.sh build examples/showcase -vet -debug -out:binaries/showcase
        ;;
    web)
        if [ -n "${EMSDK:-}" ] && [ -f "$EMSDK/emsdk_env.sh" ]; then
            export EMSDK_QUIET=1
            . "$EMSDK/emsdk_env.sh"
        fi
        : "${RAYLIB_WEB_LIB:?Set RAYLIB_WEB_LIB to an existing libraylib.web.a}"
        command -v emcc >/dev/null
        mkdir -p binaries/web
        work=$(mktemp -d "$PWD/.work/showcase.XXXXXX")
        trap 'rm -rf "$work"' EXIT
        ./scripts/odin.sh build examples/showcase -vet -target:js_wasm32 -build-mode:obj \
            -webkit-switch-workaround -define:RAYLIB_WASM_LIB=env.o "-out:$work/showcase.o"
        emcc "$work/showcase.o" "$RAYLIB_WEB_LIB" -o binaries/web/showcase.js -O1 \
            -sUSE_GLFW=3 -sSTACK_SIZE=2097152 -sINITIAL_MEMORY=33554432 \
            -sALLOW_MEMORY_GROWTH=1 -sASSERTIONS=1 -sENVIRONMENT=web \
            -sERROR_ON_UNDEFINED_SYMBOLS=0 -sWARN_ON_UNDEFINED_SYMBOLS=0
        cp "$(odin root)/core/sys/wasm/js/odin.js" binaries/web/odin.js
        cp examples/showcase/index.html binaries/web/index.html
        cp examples/showcase/assets/OFL.txt binaries/web/FONT-LICENSE.txt
        ;;
    *) echo 'Usage: scripts/build-example.sh [desktop|web]' >&2; exit 1 ;;
esac
