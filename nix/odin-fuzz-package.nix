# Canonical Nix package recipe for IgneousRed/odin-fuzz (v0.4.0+ Nix-native; no compatibility patch required).
{
  lib,
  makeWrapper,
  python3,
  odin,
  llvmPackages,
  src,
  version ? "0.4.0",
  patches ? [ ],
}:

llvmPackages.stdenv.mkDerivation {
  pname = "odin-fuzz";
  inherit version src;
  # Normalize patch paths into content-addressed single-file store paths so
  # different consumer flake source trees share one identical odin-fuzz .drv.
  patches = map (
    path:
    builtins.path {
      inherit path;
      name = builtins.baseNameOf path;
    }
  ) patches;

  nativeBuildInputs = [
    makeWrapper
    odin
  ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    odin build src -debug -thread-count:2 \
      -vet -vet-tabs -vet-using-param -vet-nil-deref -vet-uninitialized \
      -vet-atomic-access -strict-style -warnings-as-errors -vet-unused-procedures \
      -vet-packages:src,effects,functions,state \
      -strict-style-packages:src,effects,functions,state \
      -out:odin-fuzz-scan
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/libexec" "$out/share/odin-fuzz/tools"
    install -m 0755 odin-fuzz-scan "$out/libexec/odin-fuzz-scan"
    install -m 0755 odin-fuzz "$out/share/odin-fuzz/odin-fuzz"
    install -m 0644 tools/odin_fuzz.py "$out/share/odin-fuzz/tools/odin_fuzz.py"
    cp -r src "$out/share/odin-fuzz/src"

    makeWrapper "${python3}/bin/python3" "$out/bin/odin-fuzz" \
      --add-flags "-I" \
      --add-flags "$out/share/odin-fuzz/odin-fuzz" \
      --set ODIN_FUZZ_PACKAGED "1" \
      --set ODIN_FUZZ_SCANNER "$out/libexec/odin-fuzz-scan" \
      --set ODIN "${odin}/bin/odin" \
      --set ODIN_ROOT "${odin}/share" \
      --set PATH "${
        lib.makeBinPath [
          odin
          llvmPackages.clang
          llvmPackages.llvm
          llvmPackages.bintools
        ]
      }:/usr/bin:/bin:/usr/sbin:/sbin" \
      --unset HOMEBREW_PREFIX \
      --unset ODIN_FUZZ_SCANNER_CACHE
    runHook postInstall
  '';

  meta = {
    description = "First-party automated integration and invariant testing for Odin applications on macOS";
    homepage = "https://github.com/IgneousRed/odin-fuzz";
    license = lib.licenses.bsd0;
    mainProgram = "odin-fuzz";
    platforms = [ "aarch64-darwin" ];
  };
}
