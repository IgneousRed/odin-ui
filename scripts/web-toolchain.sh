# Sourced by build-example.sh after entering the locked Nix environment.
if [ -z "${PROJECT_NIX_ENVIRONMENT:-}" ] || [ -z "${PROJECT_ROOT:-}" ]; then
    echo 'Run this build through scripts/dev to use the locked web toolchain.' >&2
    exit 2
fi
if [ -z "${EMCC:-}" ] || [ ! -x "$EMCC" ]; then
    echo 'The locked environment is missing its Emscripten compiler.' >&2
    exit 2
fi
if [ -z "${RAYLIB_WEB_LIB:-}" ] || [ ! -f "$RAYLIB_WEB_LIB" ]; then
    echo 'The locked environment is missing its matching web raylib archive.' >&2
    exit 2
fi
export EMCC RAYLIB_WEB_LIB
