{
  lib,
  stdenv,
  odin,
  src,
  revision,
  version ? lib.strings.trim (builtins.readFile "${src}/VERSION"),
  development ? false,
}:

assert lib.assertMsg
  (builtins.match "[0-9a-f]{40}" revision != null || (development && revision == "unknown"))
  "odin-lint requires a full source revision; only local development may use unknown";

stdenv.mkDerivation {
  pname = "odin-lint";
  inherit version;

  src = if !development then src else lib.cleanSourceWith {
    inherit src;
    filter = path: _type:
      let
        root = toString src;
        relative = lib.removePrefix (root + "/") (toString path);
      in
      toString path == root
      || relative == "VERSION"
      || relative == "LICENSE"
      || relative == "src"
      || lib.hasPrefix "src/" relative;
  };

  nativeBuildInputs = [ odin ];
  dontConfigure = true;
  dontStrip = true;
  doCheck = false;

  buildPhase = ''
    runHook preBuild
    if ! [[ "''${NIX_BUILD_CORES:-}" =~ ^[1-9][0-9]*$ ]]; then
      echo "NIX_BUILD_CORES must be a normalized positive integer" >&2
      exit 1
    fi
    case "$(odin version)" in
      *:9a6991685|*:9a69916) ;;
      *) echo "odin-lint requires Odin compiler 9a6991685/9a69916" >&2; exit 1 ;;
    esac
    (
      set -x
      odin check src "-thread-count:$NIX_BUILD_CORES" \
        -vet -vet-tabs -vet-using-param -vet-nil-deref -vet-uninitialized \
        -vet-atomic-access -strict-style -warnings-as-errors \
        -vet-packages:src,effects,functions,state \
        -strict-style-packages:src,effects,functions,state
      odin check src "-thread-count:$NIX_BUILD_CORES" \
        -vet -vet-tabs -vet-using-param -vet-nil-deref -vet-uninitialized \
        -vet-atomic-access -strict-style -warnings-as-errors \
        -vet-unused-procedures -vet-packages:src,effects,state
    )
    odin build src -debug -o:speed "-thread-count:$NIX_BUILD_CORES" \
      -define:ODIN_LINT_REVISION=${revision} -out:odin-lint
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 odin-lint "$out/bin/odin-lint"
    install -Dm644 LICENSE "$out/share/licenses/odin-lint/LICENSE"
    runHook postInstall
  '';

  passthru = {
    inherit revision development;
  };

  meta = {
    description = "Odin architectural policy linter";
    homepage = "https://github.com/IgneousRed/odin-lint";
    license = lib.licenses.bsd0;
    mainProgram = "odin-lint";
    platforms = [ "aarch64-darwin" "x86_64-linux" ];
  };
}
