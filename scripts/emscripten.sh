# Sourced from the project root. Explicit SDK/archive selections remain portable.
if [ -n "${EMSDK:-}" ]; then
    if [ ! -f "$EMSDK/emsdk_env.sh" ]; then
        echo 'EMSDK must name an installed SDK containing emsdk_env.sh.' >&2
        exit 1
    fi
    export EMSDK_QUIET=1
    . "$EMSDK/emsdk_env.sh"
elif [ -z "${RAYLIB_WEB_LIB:-}" ]; then
    if ! command -v brew >/dev/null 2>&1; then
        echo 'Install Homebrew emscripten/raylib, or set RAYLIB_WEB_LIB and activate a compatible Emscripten SDK.' >&2
        exit 1
    fi
    emscripten_prefix=$(brew --prefix emscripten)
    node_prefix=$(brew --prefix node)
    emscripten_prefix=$(cd "$emscripten_prefix" && pwd -P)
    node_prefix=$(cd "$node_prefix" && pwd -P)
    PATH="$emscripten_prefix/bin:$node_prefix/bin:$PATH"
    export PATH
    # Keep EM_CACHE intact for isolated builds. Use canonical paths in every project.
    unset EMSDK_NODE EMSDK_PYTHON
    EM_CONFIG="$emscripten_prefix/libexec/.emscripten"
    EM_LLVM_ROOT="$emscripten_prefix/libexec/llvm/bin"
    EM_BINARYEN_ROOT="$emscripten_prefix/libexec/binaryen"
    EM_NODE_JS="$node_prefix/bin/node"
    export EM_CONFIG EM_LLVM_ROOT EM_BINARYEN_ROOT EM_NODE_JS
fi
EMCC=${EMCC:-emcc}
if ! command -v "$EMCC" >/dev/null 2>&1; then
    echo 'Emscripten is missing; activate your SDK or install Homebrew emscripten.' >&2
    exit 1
fi
export EMCC
