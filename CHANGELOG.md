# Changelog

## 0.1.1

- Use `vendor/odin_ui/` consistently in installation examples and consumer checks.
- Clarify fixed-version updates, checksum verification, build/watch integration,
  and retaining the MIT license with redistributed builds.
- No library API or behavior changes.

## 0.1.0

First public release. The API is evolving; compatibility is not promised across
minor releases before 1.0.

- Portable layout, measured text wrapping/editing, and caller-owned input state.
- Optional raylib adapter for drawing, controls, clipping and pointer input.
- Desktop and WebAssembly showcase hosts.
- Source-copy installation with a small release archive and update instructions.
- MIT license for the library; the showcase font retains its SIL Open Font License.
- Allium contract checks, headless tests, native/Wasm type checks, and a consumer
  build from the actual release archive.

Native iOS integration, grapheme-cluster editing, shaping, clipboard I/O and IME
services are not supplied by this release. Applications own their platform
integration and persistent state.
