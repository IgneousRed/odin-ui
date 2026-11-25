{ lib, stdenvNoCC, gnumake, emscripten, nodejs, raylib }:

# Canonical recipe shared by Odin UI and its web consumers. The caller supplies
# its locked SDK; the archive and runtime must always use that same derivation.
assert lib.assertMsg (raylib.version == "6.2") "Odin UI requires raylib 6.2 bindings and libraries";
stdenvNoCC.mkDerivation {
  pname = "raylib-web";
  inherit (raylib) version src;
  nativeBuildInputs = [ gnumake emscripten nodejs ];
  dontConfigure = true;
  dontStrip = true;
  enableParallelBuilding = true;

  buildPhase = ''
    runHook preBuild
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    make -C src -j"$NIX_BUILD_CORES" \
      PLATFORM=PLATFORM_WEB RAYLIB_LIBTYPE=STATIC \
      GRAPHICS=GRAPHICS_API_OPENGL_ES2
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    printf '%s\n' '#include "raylib.h"' \
      'int main(void) { return GetRandomValue(1, 1) != 1; }' > smoke.c
    emcc smoke.c -Isrc src/libraylib.web.a -sUSE_GLFW=3 \
      -sENVIRONMENT=node -sEXIT_RUNTIME=1 -o smoke.js
    node smoke.js
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib" "$out/share/licenses/raylib"
    cp src/libraylib.web.a "$out/lib/"
    cp LICENSE "$out/share/licenses/raylib/LICENSE"
    runHook postInstall
  '';

  passthru = { inherit emscripten nodejs; };
  meta = {
    description = "Raylib 6.2 static WebGL ES2 archive for the locked Emscripten SDK";
    license = lib.licenses.zlib;
    platforms = [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
  };
}
