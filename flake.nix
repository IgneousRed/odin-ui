{
  description = "Odin UI source library and locked local development tools";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/619c39f6eac5d1ed6b8f073a9414baf7034b2356";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-linux" ];
      eachSystem = nixpkgs.lib.genAttrs systems;
      environmentFor = system: profile:
        let
          pkgs = import nixpkgs { inherit system; };
          inherit (pkgs) lib;
          darwin = system == "aarch64-darwin";
          fuzz = profile == "fuzz";
          toolchain = if darwin then import ./nix/llvm23/llvm23-toolchain.nix { inherit pkgs; }
            else import ./nix/toolchain.nix { inherit pkgs; };
          inherit (toolchain) odin llvmPackages raylib;
          python = if darwin then toolchain.python else pkgs.python3;
          git = if darwin then toolchain.git else pkgs.git;
          nativeStdenv = if darwin then llvmPackages.stdenv else pkgs.stdenv;
          nodejs = pkgs.nodejs_26;
          allium = import ./nix/allium.nix { inherit pkgs; };
          emscripten = pkgs.callPackage ./nix/emscripten.nix { inherit nodejs; python3 = python; };
          webRaylib = pkgs.callPackage ./nix/web-raylib.nix { inherit emscripten nodejs raylib; };
          lintSource = pkgs.callPackage ./nix/odin-lint-source.nix { };
          fuzzSource = pkgs.callPackage ./nix/odin-fuzz-source.nix { };
          lintLock = lib.importJSON ./odin-lint.lock.json;
          fuzzLock = lib.importJSON ./odin-fuzz.lock.json;
          odinLint = pkgs.callPackage ./nix/odin-lint.nix {
            inherit odin;
            stdenv = nativeStdenv;
            inherit (lintSource) src version;
            revision = lintSource.rev;
          };
          odinFuzz = pkgs.callPackage ./nix/odin-fuzz-package.nix {
            inherit odin llvmPackages;
            python3 = python;
            inherit (fuzzSource) src version;
            patches = [ ];
          };
          browser = if darwin then pkgs.callPackage ./nix/browser-toolchain.nix { inherit nodejs; }
            else { environment.CHROMIUM_BIN = "${pkgs.chromium}/bin/chromium"; };
          version = builtins.head (lib.splitString "\n" (builtins.readFile ./VERSION));
          librarySource = pkgs.callPackage ./nix/source-package.nix {
            inherit version;
            src = builtins.path {
              path = ./.;
              name = "odin-ui-library-source";
              filter = path: _type:
                let relative = lib.removePrefix (toString ./. + "/") (toString path);
                in !(builtins.elem (builtins.baseNameOf path) [ ".DS_Store" "AGENTS.md" ]) && (
                  toString path == toString ./.
                  || builtins.elem relative [ "src" "LICENSE" "VERSION" "MIGRATING.md" "VENDORING.md" ]
                  || lib.hasPrefix "src/" relative);
            };
          };
          sdkSource = lib.importJSON ./nix/emscripten-sources.json;
          playwrightSource = lib.importJSON ./nix/playwright-sources.json;
          variables = {
            ODIN = "${odin}/bin/odin";
            ODIN_ROOT = "${odin}/share";
            ODIN_LINT_BIN = "${odinLint}/bin/odin-lint";
            ODIN_UI_SOURCE = toString librarySource;
            NODE = "${nodejs}/bin/node";
            EMCC = "${emscripten}/bin/emcc";
            RAYLIB_WEB_LIB = "${webRaylib}/lib/libraylib.web.a";
            RAYLIB_WEB_LICENSE = "${webRaylib}/share/licenses/raylib/LICENSE";
            RAYLIB_LIB_DIR = "${lib.getLib raylib}/lib";
            LIBRARY_PATH = "${lib.getLib raylib}/lib";
          } // browser.environment // lib.optionalAttrs fuzz {
            ODIN_FUZZ_BIN = "${odinFuzz}/bin/odin-fuzz";
            ODIN_FUZZ_REVISION = fuzzSource.rev;
          };
          unset = [ "DEV_POOL_ROOT" "ODIN_LINT_CACHE" "EMSDK" "EMSDK_NODE" "EMSDK_PYTHON"
            "EM_CONFIG" "EM_CACHE" "EM_FROZEN_CACHE" "EM_LLVM_ROOT" "EM_BINARYEN_ROOT"
            "EMSCRIPTEN_ROOT" "PYTHONPATH" "PYTHONHOME" "NODE_PATH" "ODIN_FUZZ_SCANNER" ]
            ++ lib.optionals (!fuzz) [ "ODIN_FUZZ_BIN" "ODIN_FUZZ_REVISION" ];
          updates = [
            { name = "nixpkgs"; current = nixpkgs.rev; kind = "github-revision"; repository = "NixOS/nixpkgs"; ref = "nixpkgs-unstable"; }
            { name = "Odin"; current = odin.version; kind = "github-release"; repository = "odin-lang/Odin"; }
            { name = "odin-lint"; current = lintSource.rev; kind = "github-revision"; repository = "IgneousRed/odin-lint"; ref = "main"; }
            allium.dependencyUpdate
            { name = "nodejs"; kind = "nodejs"; current = nodejs.version; }
            { name = "Emscripten"; current = sdkSource.version; kind = "json-version";
              url = "https://raw.githubusercontent.com/emscripten-core/emsdk/main/emscripten-releases-tags.json";
              path = [ "aliases" "latest" ]; }
          ] ++ lib.optionals darwin [
            { name = "LLVM/Clang/LLD"; current = "llvmorg-${llvmPackages.llvm.version}";
              kind = "github-release"; repository = "llvm/llvm-project"; }
            { name = "odin-fuzz"; current = fuzzSource.rev; kind = "github-release"; repository = "IgneousRed/odin-fuzz"; }
            { name = "Playwright"; current = playwrightSource.version; kind = "npm"; package = "playwright"; }
          ];
          metadata = pkgs.runCommand "odin-ui-environment-metadata" { } ''
            mkdir -p "$out/share"
            cp ${pkgs.writeText "project-environment.json" (builtins.toJSON { schema = 1; inherit variables unset; })} "$out/share/project-environment.json"
            cp ${pkgs.writeText "dependency-updates.json" (builtins.toJSON { schema = 1; dependencies = updates; })} "$out/share/dependency-updates.json"
          '';
          tools = [ odin odinLint allium python nodejs git pkgs.zip pkgs.unzip
            pkgs.gnumake pkgs.pkg-config llvmPackages.clang emscripten metadata ]
            ++ lib.optionals darwin [ browser.playwright ]
            ++ lib.optionals fuzz [ odinFuzz llvmPackages.llvm ]
            ++ lib.optionals (!darwin) [ pkgs.chromium ];
          environment = pkgs.buildEnv {
            name = "odin-ui-${profile}-environment";
            paths = tools;
            pathsToLink = [ "/bin" ];
            # buildEnv pathsToLink denotes directories; file entries become
            # directory placeholders and fail with "not a directory".
            postBuild = ''
              mkdir -p "$out/share"
              ln -s ${metadata}/share/project-environment.json "$out/share/project-environment.json"
              ln -s ${metadata}/share/dependency-updates.json "$out/share/dependency-updates.json"
            '';
          };
        in
        assert lib.assertMsg (!fuzz || darwin) "The fuzz profile requires macOS ARM64";
        assert lib.assertMsg (lintLock.revision == lintSource.rev && lintLock.version == lintSource.version)
          "Update the linter source declaration and root lock together";
        assert lib.assertMsg (fuzzLock.revision == fuzzSource.rev && fuzzLock.version == fuzzSource.version)
          "Update the fuzz source declaration and root lock together";
        { inherit environment tools variables unset librarySource emscripten webRaylib;
          dependencyCheck = (import ./nix/dependency-check.nix pkgs { schema = 1; dependencies = updates; })
            // lib.optionalAttrs darwin { preferredPython = "${python}/bin/python3"; };
        };
    in {
      lib.dependencyCheck = eachSystem (system: (environmentFor system "dev").dependencyCheck);
      packages = eachSystem (system:
        let result = environmentFor system "dev";
        in {
          default = result.librarySource;
          odin-ui-source = result.librarySource;
          dev-environment = result.environment;
          emscripten = result.emscripten;
          raylib-web = result.webRaylib;
        } // nixpkgs.lib.optionalAttrs (system == "aarch64-darwin") {
          fuzz-environment = (environmentFor system "fuzz").environment;
        });
      devShells = eachSystem (system:
        let
          pkgs = import nixpkgs { inherit system; };
          result = environmentFor system "dev";
        in { default = pkgs.mkShell (result.variables // {
          packages = result.tools;
          shellHook = ''
            unset ${builtins.concatStringsSep " " result.unset}
            export PROJECT_ROOT="$PWD"
            export PROJECT_NIX_ENVIRONMENT=${result.environment}
          '';
        }); });
    };
}
