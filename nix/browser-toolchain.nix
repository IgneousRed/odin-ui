{ lib, stdenvNoCC, fetchurl, unzip, makeWrapper, linkFarm, nodejs, playwright-driver }:
let
  sources = lib.importJSON ./playwright-sources.json;
  bundle = name: source: stdenvNoCC.mkDerivation {
    pname = "playwright-${name}";
    version = sources.version;
    src = fetchurl source;
    nativeBuildInputs = [ unzip ];
    dontConfigure = true;
    dontBuild = true;
    # Keep signed native app/framework bundles, relative links and licenses intact.
    dontFixup = true;
    unpackPhase = ''
      mkdir unpacked
      unzip -q "$src" -d unpacked
    '';
    installPhase = ''
      mkdir -p "$out"
      cp -R unpacked/. "$out/"
    '';
    meta.platforms = [ "aarch64-darwin" ];
  };
  chromium = bundle "chromium" sources.archives.chromium;
  headless = bundle "chromium-headless-shell" sources.archives.headless;
  webkit = bundle "webkit-macos-${sources.webkitDarwinRelease}" sources.archives.webkit;
  # This unchanged ffmpeg revision is also used by Playwright 1.65.0.
  ffmpeg = playwright-driver.components.ffmpeg;
  browsers = linkFarm "playwright-${sources.version}-browsers" [
    { name = "chromium-${sources.chromiumRevision}"; path = chromium; }
    { name = "chromium_headless_shell-${sources.chromiumRevision}"; path = headless; }
    { name = "webkit-${sources.webkitRevision}"; path = webkit; }
    { name = "ffmpeg-1013"; path = ffmpeg; }
  ];
  playwright = stdenvNoCC.mkDerivation {
    pname = "playwright";
    version = sources.version;
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    nativeBuildInputs = [ makeWrapper ];
    installPhase = ''
      mkdir -p "$out/lib/node_modules/playwright" "$out/lib/node_modules/playwright-core" "$out/bin"
      tar -xzf ${fetchurl sources.npm.playwright} --strip-components=1 -C "$out/lib/node_modules/playwright"
      tar -xzf ${fetchurl sources.npm.core} --strip-components=1 -C "$out/lib/node_modules/playwright-core"
      makeWrapper ${nodejs}/bin/node "$out/bin/playwright" \
        --add-flags "$out/lib/node_modules/playwright/cli.js" \
        --set PLAYWRIGHT_BROWSERS_PATH ${browsers} \
        --set PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD 1
    '';
    passthru = { inherit browsers chromium headless webkit; };
    meta = {
      description = "Released Playwright JS and matching native macOS 26 browser bundles";
      license = lib.licenses.asl20;
      platforms = [ "aarch64-darwin" ];
    };
  };
in
assert lib.assertMsg (stdenvNoCC.hostPlatform.system == "aarch64-darwin")
  "The pinned Playwright 1.65 native browser bundle currently supports aarch64-darwin/macOS 26";
{
  inherit playwright browsers chromium headless webkit;
  environment = {
    PLAYWRIGHT_PACKAGE = "${playwright}/lib/node_modules/playwright";
    PLAYWRIGHT_NODE_MODULES = "${playwright}/lib/node_modules";
    PLAYWRIGHT_MODULE = "${playwright}/lib/node_modules/playwright/index.mjs";
    PLAYWRIGHT_BROWSERS_PATH = toString browsers;
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    CHROMIUM_BIN = "${chromium}/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing";
    WEBKIT_BIN = "${webkit}/pw_run.sh";
  };
}
