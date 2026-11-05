# Odin UI

Shared, immediate UI library. Layout, text processing and interaction are
independent of operating systems and renderers.
The raylib adapter adds drawing and optional input collection. Applications own
their screens, commands, persistent state, native services and main loop.

## Packages

| Import | Responsibility |
| --- | --- |
| `odin_ui:layout` | Frame-local layout, fit/fixed/grow sizing, alignment, clipping, triggers, hit testing and horizontal/vertical scrolling. No raylib or OS imports. |
| `odin_ui:text` | Measured wrapping, truncation and UTF-8 codepoint-safe cursor/selection editing. The host supplies text measurement. |
| `odin_ui:input` | Pointer capture, click/drag cancellation, scrolling, focus traversal, DPI-coordinate conversion and safe-area bounds. Caller-owned state; no input polling. |
| `odin_ui:raylib` | Text measurement/drawing, paragraphs, buttons, fields, progress bars, colors, clipping, scrollbars, trigger hit testing and optional mouse/touch polling. |

The layout frame is parameterized by its content and color types, so a renderer
can attach typed drawing data to the same nodes without giving the layout engine
knowledge of fonts, textures or application actions. There is one geometry tree
for layout, drawing, inspection and hit testing.

## Installation

Download the source-copy archive from the
[latest release](https://github.com/IgneousRed/odin-ui/releases/latest), extract
`odin_ui/` into your project's `vendor/` folder, and commit that copy with
your project. The archive contains the packages, MIT license, version and
installation guide. It includes no compiler, raylib binaries or showcase assets.
See [the copying and updating guide](VENDORING.md) for the complete directory
layout, portable-only installation and upgrade procedure.

From your project's `src/main.odin`:

```odin
import ui "../vendor/odin_ui/raylib"
```

Build normally with `odin build src`. You can instead use
`import ui "odin_ui:raylib"` with
`odin build src -collection:odin_ui=vendor/odin_ui`. Both forms use the same
copied sources. The package table above uses collection notation for brevity.

Version `0.1.1` is an early release; the API may change before 1.0. Read the
[changelog](CHANGELOG.md) before updating your copy.

## Import and ownership

Your host owns its window and frame loop. Inside that loop, using your chosen
import path and a loaded font:

```odin
import ui "../vendor/odin_ui/raylib"
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
the allocator supplied to `begin`, which defaults to the caller's temporary
allocator. Prepared paragraph lines use that same allocator. Both `layout.begin`
and raylib's `begin` accept an explicit `allocator` and optional `storage` slice
of nodes. A nonempty slice supplies the frame's node capacity and is reused
without allocating or clearing unused nodes; omitted storage uses
`UI_NODE_CAPACITY`. For example, pass `storage = nodes[:]` for a caller-owned
array of `ui.Node`. Reuse it only after input has consumed the old frame.
Keep displayed strings and prepared lines alive through drawing and the next
input as well; reclaim them only after input has consumed the old frame. Copy text
returned by the editing helpers into application-owned storage if it must survive
the frame.
The default node limit and the depth limit are configurable through
`UI_NODE_CAPACITY` (1024) and `UI_DEPTH_CAPACITY` (32), with explicit failures
instead of partial successful layouts. `failure_node` identifies the node when
resolution detects invalid geometry, or is `INVALID_INDEX` when no particular
resolved node is responsible. This library owns no persistent application state;
application-store, persistence, migration and recovery policies belong to hosts.

`finish` must succeed before `contains`, `hit`, `begin_clip` or drawing can consume
geometry. Successful finalization sets `resolved`; calling `finish` again reads
the same result without redoing measurement. Builder calls and `action` after
success fail with `Unbalanced` and invalidate the frame. Call `begin` to start
another declaration. Do not directly change node data, geometry, viewport or
validity fields after finalization. A failed frame supplies no hits and must not
be presented. Construct a successor privately if a host needs to retain a prior
presentation after failure; the showcase deliberately asserts on failure.
Drawing a zero-initialized optional surface remains a no-op.

Wrapping prepares lines once and derives intrinsic height without rewriting
declared styles. Paragraph height fits by default and can compress in a constrained
non-scrolling container, consistently with other fit content. Scroll containers
retain the full measured content extent. Scratch decoding and drawing still use
`context.temp_allocator`; this may be reset separately when presentation data has
an explicit longer-lived allocator.

Each node owns its trigger. The portable `layout` package supplies `action`,
`node_trigger` and `hit`; the raylib package exposes the same operations with its
coordinate types. During construction, `action(&screen, index, trigger)` sets or
replaces it for buttons, fields and custom actionable nodes. `node_trigger` reads
it and `hit` returns the topmost visible trigger. Trigger paths and payload pointers are borrowed
and must remain valid until input has consumed the presented frame.

Scroll helpers take `(ui, offset, style)`. Identify a scroll container through
`action(&screen, index, trigger)`, using the same node trigger as other controls.

Fields accept `selection: text.Selection`, the same `{anchor, cursor}` byte offsets
used by `text.edit`. Pass the returned selection directly to the field options;
`cursor` separately controls caret visibility. Select all with `{0, len(value)}`
or the editing helper's `.select_all` operation. Drawing clamps offsets to UTF-8
codepoint boundaries and places the caret at `selection.cursor`.
Fields omit their underline when the resolved width leaves no room between the
text padding.
Rounded controls cap corner tessellation to bound drawing work for oversized
geometry, including controls mostly outside the visible clip.

`hsl` and `hsl_color` wrap hue angles in degrees and expect saturation/lightness
in `[0, 1]`. `hsl_blend` takes an amount in `[0, 1]`, follows the shorter hue arc
and linearly interpolates alpha along with the color. Calculated color channels
round to the nearest byte.

Application state remains authoritative. UI actions carry opaque paths/pointers;
applications translate those into their own commands and transactions. Persistent
scroll, focus and text selections remain caller-owned. UTF-8 editing is by
codepoint, not grapheme cluster; text shaping, clipboard I/O and native IME
composition/keyboard presentation are host services. A host can commit text and
selection changes through the portable editing helpers without importing an
application model into this library.

Text inputs and insertions must be valid UTF-8; boundary helpers align offsets
within valid input rather than validating malformed bytes. Paragraph wrapping
normalizes whitespace within each explicit newline-delimited paragraph to single
spaces and preserves empty paragraphs. Measurement callbacks must be deterministic
for their supplied inputs, return finite nonnegative sizes, and not retain their
transient candidate strings. Text helpers `lines`, `fit` and `edit` accept an
optional output allocator. Results may borrow unchanged input (for example, a
label that already fits); copy results when independent ownership is needed.
Allocating helpers use a frame/arena lifetime. Wrapped line strings share a buffer;
reclaim the allocator as a whole rather than freeing individual line substrings.

Input helpers expect finite logical dimensions, nonnegative insets and drag
thresholds, and finite offsets, wheel deltas and scroll limits. A nonpositive DPI
scale means 1. `input.pointer` derives a logical pointer from a mouse sample and
touch samples without polling devices; mouse ID is -1 and touch IDs are
nonnegative. The raylib `pointer` helper only collects those samples and delegates
capture continuity and coordinate conversion to that portable function.

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

## Checks and showcase

The working toolchain for the first version is:

| Tool | Tested version | Source |
| --- | --- | --- |
| Odin | `dev-2026-10:84bc3fc21` | [October release](https://github.com/odin-lang/Odin/releases/tag/dev-2026-10), [installation guide](https://odin-lang.org/docs/install/) |
| Allium CLI | `3.6.1`, including language version 3 | [Release binaries](https://github.com/juxt/allium-tools/releases/tag/v3.6.1), [installation guide](https://github.com/juxt/allium-tools#install-the-cli) |
| Desktop raylib | `6.2` on macOS ARM64 | Linked through Odin's `vendor:raylib` collection; the tested Homebrew Odin package supplies bindings and links Homebrew raylib |
| Emscripten (web builds) | `6.0.13` | [SDK installation guide](https://emscripten.org/docs/getting_started/downloads.html) |
| Web raylib | `6.2`, static, OpenGL ES 2 | [Tagged source](https://github.com/raysan5/raylib/tree/6.2) |

GitHub Actions runs the complete check suite on Ubuntu 24.04 using the official
Odin `dev-2026-10` archive (including its bundled raylib) and Allium `3.6.1`.
Downloaded tool archives are verified by SHA-256. The desktop and linked web
showcase were also exercised with the macOS toolchain listed above.

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

Checks validate shell-script syntax and the shared Allium specification, and run
portable tests and raylib geometry/text tests without opening a window, plus native
and Wasm showcase type checks.
Odin commands use the compiler's `-vet` diagnostics. No separate linter is configured;
selection remains an open decision in [TODO.md](TODO.md).
Named regression cases reference the specification's lifecycle, ownership and
measurement invariants; the specification check itself does not execute the Odin
implementation. Checks also package the actual release ZIP, verify its checksum,
extract it into a separate consumer project, run a headless native program and
check the Wasm target using only the copied packages and ordinary Odin commands.
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

`spec/ui-layout.allium` owns the shared layout contract and is checked in this
repository. Consumer specs define and validate their own application behavior
and ownership boundaries without importing the library's specification into
their check sets.

Original project code is copyright IgneousRed and is available under the
[MIT license](LICENSE), including commercial use. Keep its copyright and license
notice with copied library code. Odin and raylib retain their own licenses and
are not copied into this repository.
The showcase embeds Atkinson Hyperlegible Next with its SIL Open Font License
in `examples/showcase/assets/OFL.txt`. Its exact source revision and binary
checksum are recorded in [the asset manifest](examples/showcase/assets/VENDORING.md).
Library consumers continue to supply their own fonts.

External reviewer selection is recorded in `TODO.md`.

## Maintaining releases

Repository development builds use `scripts/odin.sh`, which registers this
checkout's `src/` as the `odin_ui` collection. Consumers do not need this helper.

Before a release, update `VERSION` (version, source and tagged release URL),
`VENDORING.md` and `CHANGELOG.md`, then run:

```sh
./scripts/check.sh
./scripts/package.sh
```

The ZIP in `binaries/` is the same artifact exercised by the consumer check. It
contains one `odin_ui/` folder ready to copy. Packaging prepares and validates a
new archive privately before replacing the previous ZIP, and produces
`binaries/SHA256SUMS.txt`. Tag the checked commit, push it and attach both files
to the corresponding GitHub release. GitHub also supplies full repository source
archives; those include the tests and showcase as well.
