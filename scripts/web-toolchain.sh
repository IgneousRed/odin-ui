# Explicit archives bypass Homebrew and the shared cache entirely.
if [ -n "${EMSDK:-}${EMCC:-}" ] && [ -z "${RAYLIB_WEB_LIB:-}" ]; then
    echo 'Set RAYLIB_WEB_LIB to an archive built with the selected Emscripten toolchain.' >&2
    exit 1
fi
. ./scripts/emscripten.sh
if [ -n "${RAYLIB_WEB_LIB:-}" ]; then
    if [ ! -f "$RAYLIB_WEB_LIB" ]; then
        echo "Web raylib archive missing: $RAYLIB_WEB_LIB" >&2
        exit 1
    fi
else
    raylib_web_directory=$(python3 -B tools/shared_raylib.py --odin "${ODIN:-odin}")
    RAYLIB_WEB_LIB="$raylib_web_directory/lib/libraylib.web.a"
fi
export RAYLIB_WEB_LIB
