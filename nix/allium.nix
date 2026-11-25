{ pkgs }:
let
  inherit (pkgs) lib stdenv;
  version = "3.7.2";
  # Official v3.7.2 release asset SHA-256 digests, published by GitHub's API:
  # https://api.github.com/repos/juxt/allium-tools/releases/tags/v3.7.2
  artifacts = {
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      sha256 = "3de3acfbc7874d92c63ce4fbb92ff4333348743471b885ed15318e9401f6fc36";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      sha256 = "6a21afc1347bfcdb82e566ddf696e1e0b5aa56fe4acbc3428bd29f33c00a2465";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      sha256 = "f299548d8401a761ea5059abd202d1918da4c4ec445dc6c62db287755bf961da";
    };
  };
  artifact = artifacts.${stdenv.hostPlatform.system}
    or (throw "Allium ${version}: no supported release artifact for ${stdenv.hostPlatform.system}");
  license = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/juxt/allium-tools/v${version}/LICENSE";
    sha256 = "1126322e2cc8d165adc4c792eeb195717de2bcc7b39be1ce77959d78e87ef685";
  };
in pkgs.stdenvNoCC.mkDerivation {
  pname = "allium";
  inherit version;
  src = pkgs.fetchurl {
    url = "https://github.com/juxt/allium-tools/releases/download/v${version}/allium-${artifact.target}.tar.gz";
    inherit (artifact) sha256;
  };
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux pkgs.autoPatchelfHook;
  buildInputs = lib.optional stdenv.hostPlatform.isLinux stdenv.cc.cc.lib;
  installPhase = ''
    runHook preInstall
    install -Dm755 allium "$out/bin/allium"
    install -Dm644 ${license} "$out/share/licenses/allium/LICENSE"
    runHook postInstall
  '';
  passthru.dependencyUpdate = {
    name = "Allium";
    current = version;
    kind = "github-release";
    repository = "juxt/allium-tools";
  };
  meta = {
    description = "Allium specification language CLI";
    homepage = "https://github.com/juxt/allium-tools";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "allium";
    platforms = builtins.attrNames artifacts;
  };
}
