{ lib, stdenv, stdenvNoCC, fetchurl, python3, nodejs, makeWrapper, autoPatchelfHook, zlib }:
let
  sources = lib.importJSON ./emscripten-sources.json;
  archive = sources.archives.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "emscripten";
  version = sources.version;
  src = fetchurl archive;
  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ stdenv.cc.cc.lib zlib ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  sourceRoot = "install";
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/emsdk" "$out/bin" "$out/share/licenses/emscripten"
    cp -R . "$out/share/emsdk/"
    sdk="$out/share/emsdk"
    test -f "$sdk/emscripten/emcc.py"
    test -d "$sdk/emscripten/node_modules"
    cat > "$out/share/emscripten-config" <<EOF
    LLVM_ROOT = '$sdk/bin'
    BINARYEN_ROOT = '$sdk'
    EMSCRIPTEN_ROOT = '$sdk/emscripten'
    NODE_JS = '${nodejs}/bin/node'
    JS_ENGINES = [NODE_JS]
    FROZEN_CACHE = True
    EOF
    ${lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
      # Native SDK tools must run during cache preparation, before fixupPhase.
      autoPatchelf "$out/share/emsdk"
    ''}
    # Populate the shared SDK sysroot/library cache once, before it becomes
    # immutable. Runtime builds use it read-only; no project copies or locks.
    export EM_CONFIG="$out/share/emscripten-config"
    export EM_FROZEN_CACHE=0
    export EMCC_CORES="$NIX_BUILD_CORES"
    export EMSDK_PYTHON=${python3}/bin/python3
    export PATH=${lib.makeBinPath [ nodejs python3 ]}:"$PATH"
    printf '%s\n' '#include <GLES2/gl2.h>' \
      'int main(int argc, char **argv) { if (argc > 10) glClear(GL_COLOR_BUFFER_BIT); return 0; }' > "$TMPDIR/smoke.c"
    ${python3}/bin/python3 "$sdk/emscripten/emcc.py" "$TMPDIR/smoke.c" \
      -sUSE_GLFW=3 -sENVIRONMENT=node -sEXIT_RUNTIME=1 -o "$TMPDIR/smoke.js"
    ${nodejs}/bin/node "$TMPDIR/smoke.js"
    # UI uses O1, Lantern uses O0/O2. Keep the concrete consumer variants here.
    for optimization in 0 1 2; do
      ${python3}/bin/python3 "$sdk/emscripten/emcc.py" "$TMPDIR/smoke.c" \
        -O"$optimization" -g -sUSE_GLFW=3 -sSTACK_SIZE=2097152 -sINITIAL_MEMORY=33554432 \
        -sALLOW_MEMORY_GROWTH=1 -sASSERTIONS=1 -sENVIRONMENT=web \
        -sERROR_ON_UNDEFINED_SYMBOLS=0 -sWARN_ON_UNDEFINED_SYMBOLS=0 -o "$TMPDIR/web.js"
    done
    unset EM_FROZEN_CACHE
    for program in emcc em++ emar emranlib emcmake emconfigure emmake emrun embuilder; do
      makeWrapper ${python3}/bin/python3 "$out/bin/$program" \
        --add-flags "$sdk/emscripten/$program.py" \
        --set EM_CONFIG "$out/share/emscripten-config" \
        --set EM_FROZEN_CACHE 1 --unset EM_CACHE \
        --unset EM_LLVM_ROOT --unset EM_BINARYEN_ROOT \
        --set EMSDK_PYTHON ${python3}/bin/python3 \
        --prefix PATH : ${lib.makeBinPath [ nodejs python3 ]}
    done
    cp "$sdk/emscripten/LICENSE" "$out/share/licenses/emscripten/LICENSE"
    cp ${fetchurl sources.licenses.llvm} "$out/share/licenses/emscripten/LLVM-LICENSE.TXT"
    cp ${fetchurl sources.licenses.binaryen} "$out/share/licenses/emscripten/BINARYEN-LICENSE"
    runHook postInstall
  '';
  passthru = { inherit nodejs; sdkRelease = sources.release; };
  meta = {
    description = "Fixed upstream Emscripten 7 SDK with its matching LLVM 24 and Binaryen";
    license = [ lib.licenses.mit lib.licenses.ncsa lib.licenses.asl20 ];
    platforms = builtins.attrNames sources.archives;
  };
}
