{ lib, runCommand, unzip, src, version }:

# src may be an exact repository source or the existing checksum-pinned release
# ZIP. It is supplied by the consumer; this recipe never advances that pin.
runCommand "odin-ui-${version}-source" {
  nativeBuildInputs = [ unzip ];
  passthru = { inherit src version; };
  meta.license = lib.licenses.mit;
} ''
  mkdir -p "$out"
  if [ -d "${src}/src/layout" ]; then
    cp -R "${src}/src/layout" "${src}/src/text" "${src}/src/input" "${src}/src/raylib" "$out/"
    cp "${src}/LICENSE" "${src}/VERSION" "${src}/MIGRATING.md" "$out/"
    cp "${src}/VENDORING.md" "$out/README.md"
  else
    unzip -q "${src}" -d unpacked
    cp -R unpacked/odin_ui/. "$out/"
  fi
  test -f "$out/raylib/raylib.odin"
  test -f "$out/LICENSE"
  test "$(head -n 1 "$out/VERSION")" = ${lib.escapeShellArg version}
''
