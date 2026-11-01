# Odin UI

Shared, immediate UI extracted from Gond, Lantern House and Devil's Arena. Layout,
text processing and interaction are independent of operating systems and renderers.
The raylib adapter adds drawing and optional input collection. Applications own
their screens, commands, persistent state, native services and main loop.

## Packages

| Import | Responsibility |
| --- | --- |
| `odin_ui:layout` | Frame-local layout, fit/fixed/grow sizing, alignment, clipping, hit geometry and horizontal/vertical scrolling. No raylib or OS imports. |
| `odin_ui:text` | Measured wrapping, truncation and UTF-8 codepoint-safe cursor/selection editing. The host supplies text measurement. |
| `odin_ui:input` | Pointer capture, click/drag cancellation, scrolling, focus traversal, DPI-coordinate conversion and safe-area bounds. Caller-owned state; no input polling. |
| `odin_ui:raylib` | Text measurement/drawing, paragraphs, buttons, fields, progress bars, colors, clipping, scrollbars, trigger hit testing and optional mouse/touch polling. |

The layout frame is parameterized by its content and color types, so a renderer
can attach typed drawing data to the same nodes without giving the layout engine
knowledge of fonts, textures or application actions. There is one geometry tree
for layout, drawing, inspection and hit testing.

## Import and ownership

Use `scripts/odin.sh` in place of `odin` for builds/checks/tests, or supply
`-collection:odin_ui=/absolute/path/to/odin-ui/src` to the compiler. Consumers may
choose another checkout through their `ODIN_UI_ROOT` environment variable. Keep
the library checkout alongside the game repositories; Gond's default is
`../../Repositories/odin-ui` relative to its root.

```odin
import ui "odin_ui:raylib"
import rl "vendor:raylib"

screen: ui.UI
ui.begin(&screen, width, height, {direction = .vertical, gap = 8})
ui.paragraph(&screen, font, "A paragraph wraps to its resolved width.", 20, rl.WHITE)
ui.button(&screen, font, "Continue", 20, rl.BLUE, rl.DARKBLUE, {path = "continue"})
if ui.finish(&screen) == nil {
    ui.draw(&screen)
}
```

`text` is an intrinsically measured, centered label; `paragraph` wraps after width
resolution. `row`, `column`, `scroll_row`, `scroll_column`, `separator`, `space`,
`button`, `field` and `bar` use the same frame. Use `begin_clip` for custom drawing;
pair a successful call with raylib's `EndScissorMode`.

The raylib text, paragraph, button and field builders copy displayed strings into
the caller's temporary allocator. Frames use that allocator too. The pure
`layout.begin` also accepts an explicit allocator. Keep its storage alive while
the frame is displayed and while evaluating the next input against it; reclaim
that storage only after input has consumed the old frame. Copy text returned by
the editing helpers into application-owned storage if it must survive the frame.
Node and depth limits are configurable through `UI_NODE_CAPACITY` (1024) and
`UI_DEPTH_CAPACITY` (32), with explicit failures instead of partial successful
layouts. No mutable singleton or relational engine is required by the library.

Each node owns its trigger. `action(&screen, index, trigger)` sets or replaces it
for buttons, fields and custom actionable nodes; `node_trigger` reads it and `hit`
returns the topmost visible trigger. Trigger paths and payload pointers are borrowed
and must remain valid until input has consumed the presented frame.

Application state remains authoritative. UI actions carry opaque paths/pointers;
applications translate those into their own commands and transactions. Persistent
scroll, focus and text selections remain caller-owned. UTF-8 editing is by
codepoint, not grapheme cluster; text shaping, clipboard I/O and native IME
composition/keyboard presentation are host services. A host can commit text and
selection changes through the portable editing helpers without importing an
application model into this library.

## Platforms

The portable packages use only Odin core libraries. The raylib adapter uses the
same sources on desktop, WebAssembly and Android. No platform test is treated as
evidence for a different target.

Desktop hosts run their own frame loop. Web hosts call exported frame functions
from `requestAnimationFrame`; Android hosts retain their lifecycle, native
keyboard and JNI integration. Supply consistent logical pointer/viewport units.
The Web showcase supplies a frame arena and restores its saved Odin context on
each callback. This prevents Odin allocations from growing Wasm memory behind
Emscripten's typed heap views; other hosts must coordinate memory growth or use
the same arena pattern.
When drawing with a DPI transform, pass that same scale to `draw`/`begin_clip` so
framebuffer scissor bounds match the logical geometry. Safe-area insets can be
supplied as root padding. Native iOS integration is not provided or claimed by
this extraction; it requires its own raylib host and target validation.

Gond's CMake configuration tracks the shared sources as native build dependencies.
Both games' development fingerprints include shared sources, so editing the library
uses their existing rebuild/recovery mechanism without changing saved state.

## Checks and showcase

The working toolchain for the first version is:

| Tool | Tested version | Source |
| --- | --- | --- |
| Odin | `dev-2026-10:84bc3fc21` | [October release](https://github.com/odin-lang/Odin/releases/tag/dev-2026-10), [installation guide](https://odin-lang.org/docs/install/) |
| Allium CLI | `3.6.1`, including language version 3 | [Release binaries](https://github.com/juxt/allium-tools/releases/tag/v3.6.1), [installation guide](https://github.com/juxt/allium-tools#install-the-cli) |
| Desktop raylib | `6.2` on macOS ARM64 | Linked through Odin's `vendor:raylib` collection; the tested Homebrew Odin package supplies bindings and links Homebrew raylib |
| Emscripten (web builds) | `6.0.13` | [SDK installation guide](https://emscripten.org/docs/getting_started/downloads.html) |
| Web raylib | `6.2`, static, OpenGL ES 2 | [Tagged source](https://github.com/raysan5/raylib/tree/6.2) |

Install Odin and Allium using the linked upstream instructions, put their
executables on `PATH`, and confirm `odin version` and `allium --version` before
running checks. For an exact Allium version, use the 3.6.1 release archive for
your OS/architecture; a package manager may supply a different version. Odin also
needs the platform's native compiler/linker (Xcode Command Line Tools on macOS).
Keep the compiler's `base`, `core` and `vendor` collections with it. Native raylib
linking follows that Odin distribution's vendor setup.

The portable library needs no Emscripten installation. The full check script also
type-checks the Wasm target, but does not link a web executable. Build scripts use
installed dependencies and download no libraries.

```sh
./scripts/check.sh
./scripts/build-example.sh desktop
./binaries/showcase
```

Checks run the shared Allium contract, portable tests and raylib geometry/text
tests without opening a window, plus native and Wasm showcase type checks.
Consumer projects validate their own code and application integration; they do
not invoke this repository’s check suite.
The showcase demonstrates resize, wrapping, buttons, fields, progress and shared
input handling. It is an example host rather than a replacement application shell.
For a runtime smoke check, click the counter, press it and release outside to
confirm cancellation, edit the field (including backspacing over `é`), and resize
to a narrow and a wide viewport. In the browser, move focus away from the canvas
during a press and confirm that releasing does not increment the counter. These
checks exercise the linked host; a successful type check alone does not cover them.

To build its web files, provide an activated Emscripten SDK and a raylib static
library built with that SDK. Reuse existing compatible installations or prepare
the tested versions manually from the repository root (requires Git, Python 3
and Make):

```sh
git clone --depth 1 --branch 6.0.13 https://github.com/emscripten-core/emsdk.git .work/emsdk
.work/emsdk/emsdk install 6.0.13
.work/emsdk/emsdk activate 6.0.13
```

Then, in Bash or Zsh, activate the SDK and build raylib and the showcase:

```sh
source .work/emsdk/emsdk_env.sh
emcc --version
git clone --depth 1 --branch 6.2 https://github.com/raysan5/raylib.git .work/raylib
make -C .work/raylib/src -j4 PLATFORM=PLATFORM_WEB RAYLIB_LIBTYPE=STATIC GRAPHICS=GRAPHICS_API_OPENGL_ES2
EMSDK="$PWD/.work/emsdk" RAYLIB_WEB_LIB="$PWD/.work/raylib/src/libraylib.web.a" \
    ./scripts/build-example.sh web
```

For existing installations, use the same final command with their absolute paths.
The archive must contain Wasm objects and use the same Emscripten version as the
final link. The build uses Odin's `RAYLIB_WASM_LIB=env.o` binding mode to resolve
raylib through that archive. The HTML host supplies Odin runtime imports alongside
Emscripten's imports; replacing it with a generic Emscripten page is insufficient.

Serve `binaries/web/` through your existing static host with a Wasm MIME type. Final
example outputs belong in `binaries/`; temporary builds, captures and experiments
belong in `.work/`.

## Specification and provenance

`spec/ui-layout.allium` owns the shared layout contract, extracted from Gond, and
is checked in this repository. Consumer specs define and validate their own
application behavior and ownership boundaries without importing the library's
specification into their check sets.

The source combines the three existing UI implementations, including Gond's
controls, selection painting and HSL helpers; the games' wrapping and scrollbars;
and Devil's Arena's custom clipping support. Original project code credits
IgneousRed and retains the included PolyForm Noncommercial license. Odin and
raylib retain their own licenses and are not copied into this repository.
The showcase reuses Atkinson Hyperlegible Next from Devil's Arena, unchanged,
with its SIL Open Font License in `examples/showcase/assets/OFL.txt`. Library
consumers continue to supply their own fonts.

External reviewer selection is recorded in `TODO.md`.
