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

The normal raylib interface has two explicit passes: layout declares and measures
geometry; paint supplies appearance using that resolved geometry. Hit testing and
painting share one caller-owned geometry buffer. Painting executes in call order
without copying the tree or allocating a draw list. The portable layout frame is
still parameterized by content and color types for existing integrations.

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

Development version `0.2.1` is not yet published; released archives are listed
on the [releases page](https://github.com/IgneousRed/odin-ui/releases). The API
may change before 1.0. Read the [changelog](CHANGELOG.md) before updating your copy.

## Import and ownership

Your host owns the window, fonts, frame loop and interaction state:

```odin
import ui "../vendor/odin_ui/raylib"
import rl "vendor:raylib"

builder: ui.Layout_Builder
nodes: [128]ui.Layout_Node
ui.begin_layout(&builder, width, height,
    {direction = .vertical, gap = 8}, storage = nodes[:])
label := ui.paragraph_layout(&builder, font, "A paragraph wraps during layout.", 20)
button := ui.button_layout(&builder, font, "Continue", 20, {path = "continue"})
resolved, failure := ui.finish_layout(&builder)
assert(failure == nil)
hovered := ui.contains_resolved(resolved, button, mouse)

paint: ui.Paint
ui.begin_paint(&paint, resolved)
ui.paint_text(&paint, label, {color = rl.WHITE})
ui.paint_button(&paint, button, {
    background = rl.BLUE if hovered else rl.DARKBLUE,
    foreground = rl.WHITE,
})
ui.end_paint(&paint)
```

Keep the builder at the same address after beginning layout. `Node_Handle` and
`Resolved_Layout` are borrowed, opaque values: do not construct or edit their
fields. A handle belongs to one builder generation. `begin_layout` invalidates
all its old handles and resolved views, even when it reuses the same storage.
`geometry` returns a value snapshot with rectangle, clip, radius, scroll limit,
trigger and child index; it never returns mutable node access. Builder and node
fields are implementation storage, not a mutation API. Shared storage may not be
reused by another live builder. Destroyed builders invalidate all borrowed values.

`Geometry` contains sizing, direction, padding, gaps, alignment, scrolling,
clipping and the hit radius. `row_layout` and `column_layout` open containers;
`close_layout` closes them. `box_layout`, `text_layout`, `paragraph_layout`,
`button_layout`, `field_layout`, `bar_layout`, `separator_layout` and
`space_layout` return handles. `layout_action`, `set_geometry` and
`measure_layout_width` operate during declaration. Revised geometry must remain
valid. A successful `finish_layout` returns the resolved view and nil failure;
repeating it reuses prepared text without measuring again. Failed layouts supply
no hits or paint operations. Node/depth limits and failure values retain the
portable layout contracts described below. For a production alternative to the
showcase assertion, see [host-owned frame failure handling](docs/frame-failures.md)
and its [runnable example](examples/failure_policy/failure_policy.odin).

Text content, font and pixel size enter layout. Strings are copied into the
supplied allocator; prepared runes, wrapped lines, line offsets and field cursor
positions have that same frame/arena lifetime. Fonts remain borrowed host
resources. Wrapping completes inside `finish_layout`: width resolution is independent of
intrinsic height, so a second geometry resolution incorporates wrapped heights
without changing the widths used for preparation. Reclaim the arena only after painting
and input against the presented frame have finished. Scratch measurement uses
`context.temp_allocator`; it can be reset separately after layout when prepared
results use a longer-lived allocator. Reuse a node array and arena to bound memory
across frames. No geometry allocation is needed when a node slice is supplied.

A paint pass may be empty. Paint operations return false for invalid, stale,
cross-builder or inappropriate text handles, and after `end_paint`. Fully clipped
valid commands are successful no-ops. `paint_box`, `paint_text`, `paint_button`,
`paint_field`, `paint_bar` and `paint_scrollbar` execute immediately in supplied
order using resolved clips. Each command contains its complete appearance; colors
have no implicit contrast or disabled-state interpretation. A button draws one
background. Borders and focus indicators occupy existing bounds. A field accepts
selection and caret visibility during paint; blinking and recoloring allocate no
memory and perform no text measurement. Field cursor positions keep long text
stable while the caret blinks. UTF-8 offsets are clamped to codepoint boundaries.

Paint cannot change rectangles, clips, scroll extents or hit shapes. A change to
text, font, wrapping, padding, radius or dimensions requires another layout;
appearance-only changes can reuse the resolved view. The normal API deliberately
requires even fixed-slot text to be prepared during layout: there is no implicit
late-content measurement in paint. Fixed-size geometry clips overflowing content
to the node's resolved bounds. Custom rendering can use the `geometry` snapshot
and the portable clipping helpers; hosts own renderer effects and their ordering.

Input remains separate from appearance. Query `contains_resolved` or
`hit_resolved` between the passes, then choose hover, pressed, focused, selected
and disabled colors. `hit_resolved` searches reverse declaration order. A host
that paints overlapping nodes in a different order chooses the matching hit order
with `contains_resolved`. Disabled colors alone do not disable activation. Stable
trigger identities own persistent capture and focus; frame handles identify only
the current layout. Trigger paths and payloads are borrowed through presented-frame
input. Hosts choose surface order, for example main screen, modal backdrop,
dialog, tooltip. See [the migration guide](MIGRATING.md) for existing integrations.

The compatibility `UI`/`Node`/`Style`, `begin`/`finish`/`draw` and original widget
builders remain available for external consumers. They retain their original
combined drawing payloads and allocation behavior; they are not the normal
two-pass contract. Do not mutate finalized compatibility nodes. Both interfaces
retain `UI_NODE_CAPACITY` (1024), `UI_DEPTH_CAPACITY` (32), finite geometry checks,
explicit capacity/unbalanced failures and caller-owned presentation lifetimes.

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
scale means 1. `input.scroll` bounds the current offset before applying wheel
input or starting a drag, including when the content extent has shrunk.
`input.pointer` derives a logical pointer from a mouse sample and
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
When drawing with a DPI transform, pass that same scale to `begin_paint` (or compatibility `draw`/`begin_clip`) so
framebuffer scissor bounds match the logical geometry. Safe-area insets can be
supplied as root padding. Native iOS integration is not provided or claimed by
this extraction; it requires its own raylib host and target validation.

## Checks and showcase

The development check toolchain is:

| Tool | Tested version | Source |
| --- | --- | --- |
| Odin | `dev-2026-11a`, compiler `9a6991685` (also printed as `9a69916`) | [November release](https://github.com/odin-lang/Odin/releases/tag/dev-2026-11a), [installation guide](https://odin-lang.org/docs/install/) |
| Shared Odin linter runner | Python 3.9+ standard library, Git, authenticated GitHub access | [Pinned integration contract](https://github.com/IgneousRed/odin-lint/blob/949293b8a7fcff8f72927b5afb5c5ada8b2df896/docs/integration.md) |
| Allium CLI | `3.6.1`, including language version 3 | [Release binaries](https://github.com/juxt/allium-tools/releases/tag/v3.6.1), [installation guide](https://github.com/juxt/allium-tools#install-the-cli) |
| Desktop raylib | `6.2` on macOS ARM64 | Linked through Odin's `vendor:raylib` collection; the tested Homebrew Odin package supplies bindings and links Homebrew raylib |
| Node.js | 18+ standard library; no npm packages | Host regression checks and optional Chromium smoke runner |
| Emscripten (web builds) | Installed Homebrew version | [Homebrew package](https://formulae.brew.sh/formula/emscripten) |
| Web raylib | Installed Homebrew version, static, OpenGL ES 2 | Source and SHA-256 from the installed Homebrew formula |

GitHub Actions runs the complete check suite on Ubuntu 24.04 using the official
Odin `dev-2026-11a` archive (including its bundled raylib) and Allium `3.6.1`.
Downloaded tool archives are verified by SHA-256. The desktop and linked web
showcase were previously exercised with Odin `dev-2026-10:84bc3fc21` on macOS;
the default check suite does not link or playtest the web showcase.
`./scripts/check-web.sh` provides a separate linked Chromium runtime check.

Install Odin and Allium using the linked upstream instructions, put their
executables on `PATH`, and confirm `odin version` and `allium --version` before
running checks. For an exact Allium version, use the 3.6.1 release archive for
your OS/architecture; a package manager may supply a different version. Odin also
needs the platform's native compiler/linker (Xcode Command Line Tools on macOS).
Keep the compiler's `base`, `core` and `vendor` collections with it. Native raylib
linking follows that Odin distribution's vendor setup.

The portable library needs no Emscripten installation. The default check script
also type-checks the Wasm target, but does not link a web executable. The optional
web check below links and runs the actual host. The Homebrew web resolver may
download checksum-verified raylib source when its shared cache is cold; explicit
SDK/archive builds use only the dependencies you provide. No script installs a
compiler or browser.

```sh
./scripts/check.sh
./scripts/build-example.sh desktop
./binaries/showcase
```

Checks validate shell-script syntax and the shared Allium specification, and run
portable tests and raylib geometry/text tests without opening a window, plus native
and Wasm showcase type checks. Maintained drawing-capture cases exercise caret
visibility, UTF-8 and multiline selections, narrow fields and ordinary button
centering against real raylib measurements. The capture package runs serially
because raylib line spacing is process-global; macOS interposes shared-library
drawing calls and Linux wraps the bundled static archive's drawing symbols.
Node checks execute the actual HTML host's keyboard routing, frame-failure
handling and Odin import forwarding. Node 18+ is required; set `NODE` to select
an executable explicitly. The standard suite also checks the smoke-build define
with the same compiler vetting as the normal showcase.
Compiler gates use maximal compatible first-party vetting: `-vet -vet-tabs
-vet-using-param -vet-nil-deref -vet-uninitialized -vet-atomic-access
-strict-style -warnings-as-errors`, with explicit first-party package scopes.
Unused-procedure checks are separate and limited to the closed showcase and
copied-consumer entry points; reusable library APIs and attributed test entry
points remain under every other check. After editing code, run
`./scripts/check.sh` before completing the change: all applicable Odin compiler
checks must pass before the GitHub-pinned shared Odin linter runs. Every shared
rule runs; setup or analysis failure is not a pass.
Named regression cases reference the specification's lifecycle, ownership and
measurement invariants; the specification check itself does not execute the Odin
implementation. Checks also package the actual release ZIP, verify its checksum,
extract it into a separate consumer project, run a headless native program and
check the Wasm target using only the copied packages and ordinary Odin commands.
Consumer projects validate their own code and application integration; they do
not invoke this repository’s check suite.

### Shared Odin linting

[`odin-lint.lock.json`](odin-lint.lock.json) pins
[`IgneousRed/odin-lint`](https://github.com/IgneousRed/odin-lint) to full commit
`949293b8a7fcff8f72927b5afb5c5ada8b2df896`.
[`tools/run-odin-lint.py`](tools/run-odin-lint.py) is copied unchanged from that
same commit. It fetches that GitHub revision through HTTPS Git and builds it with
the required Odin compiler. No sibling linter checkout, home-directory skill,
OLS installation or Python package is a runtime dependency. Its only cache and
temporary source builds live in ignored `.work/odin-lint/`.

For this private repository, authenticate GitHub CLI with an account that can
read the linter repository and configure Git's credential helper:

```sh
gh auth login --hostname github.com
gh auth setup-git --hostname github.com
./scripts/check.sh
```

CI uses the same check script. Configure the Actions secret
`ODIN_LINT_GITHUB_TOKEN` with read access to `IgneousRed/odin-lint`; the consuming
repository's default `GITHUB_TOKEN` does not normally grant that access. The job
configures Git via `gh auth setup-git` and fails if the secret is missing. Never
store credentials in the lock file or repository.

The check script runs library `-no-entry-point` checks and package tests, native
and Wasm showcase checks (including `RAYLIB_WASM_LIB=env.o`), portable Wasm library
checks, the native/Wasm failure-policy example, and the packaged-source consumer
before invoking:

```sh
python3 tools/run-odin-lint.py odin-lint.lock.json \
    --root . --source-root src --collection odin_ui=src src examples tests
```

Run `./scripts/check.sh` for verification so the compiler precondition is enforced.
The analyzer receives the same `odin_ui` collection as `scripts/odin.sh`. The
root includes all saved repository consumers; selected diagnostics cover library,
showcase and test sources. The copied-source consumer is compiled separately in
ignored `.work/` with ordinary Odin commands; generated copies are not lint input.
Exit `0` means clean, `1` means lint findings, and `2` means setup/usage/analysis
failure. Findings remain failures; there are no disabled or suppressed rules.
Analyzer signal termination or an unexpected child status is reported explicitly
and normalized to analysis failure (exit `2`).
Record unresolved compiler, analysis and source findings in [TODO.md](TODO.md).
A run that does not complete analysis has unknown rule counts, even when its
output contains no diagnostics; it is never a clean result.

Public library APIs may be used outside this checkout. Review visibility and
interface-migration suggestions against those external consumers before changing
an API; repository-local evidence alone cannot justify narrowing it. See the
[pinned rules and analysis limits](https://github.com/IgneousRed/odin-lint/blob/949293b8a7fcff8f72927b5afb5c5ada8b2df896/docs/rules.md).

To upgrade the pin deliberately:

1. Choose a published full 40-character commit and review its `README.md`,
   `docs/integration.md`, and `docs/rules.md` through GitHub at that revision.
2. Stage all four required upstream files from that **same** revision in a new
   ignored `.work/` directory using authenticated `gh api` and
   `Accept: application/vnd.github.raw+json`: `README.md`, `docs/integration.md`,
   `docs/rules.md`, and `scripts/run-odin-lint.py`. Read the staged docs, validate
   the runner's Python syntax, and prepare a staged root lock containing the
   repository and exact revision. Failed downloads must leave the installed pair
   untouched; the pinned integration guide contains the complete staging commands.
3. Install the reviewed runner and matching lock together, without running lint
   between replacements. Update documented revision links and any required
   compiler version/CI archive checksum. Verify an empty cache entry for the new
   revision with a real GitHub bootstrap and `--version`, then run
   `./scripts/check.sh`. Compiler failures stop lint; retain concrete source and
   analysis failures instead of suppressing rules or treating skipped lint as clean.
4. Review and commit the runner, lock and related integration changes together.
   Branch/tag movement upstream never changes the pinned revision. Preserve the
   runner's repository/compiler/host cache identity; `.work/odin-lint/` is the only
   runtime cache. The pinned policy keeps `SIMPLIFY001` imperative; apply an inlining
   change only after checking its actual call binding and semantic safety.

The showcase demonstrates resize, wrapping, buttons, fields, progress and shared
input handling. It is an example host rather than a replacement application shell.
For a runtime smoke check, click the counter, press it and release outside to
confirm cancellation, edit the field (including backspacing over `é`), and resize
to a narrow and a wide viewport. In the browser, move focus away from the canvas
during a press and confirm that releasing does not increment the counter. These
checks exercise the linked host; a successful type check alone does not cover them.

Web builds use the installed Homebrew Emscripten and raylib versions and one
shared WebAssembly archive under `~/.local/share/dev-pool/raylib-web/`:

```sh
brew install emscripten raylib
./scripts/build-example.sh web
```

The archive is rebuilt automatically when either Homebrew toolchain changes,
then reused by other projects and worktrees. Builds verify the source SHA-256
from the installed Homebrew formula, check Odin's raylib binding version,
serialize concurrent builds and publish only after linking and running a smoke
test. Failed rebuilds leave older versions intact. Set `DEV_POOL_ROOT` to choose
another shared pool. Native raylib still comes through Odin/Homebrew; browser
builds use the shared WebAssembly archive via `RAYLIB_WASM_LIB=env.o` binding mode.
To use an existing SDK/archive on Linux or another supported Emscripten host,
activate the SDK and supply an absolute archive path built with that SDK:

```sh
RAYLIB_WEB_LIB=/absolute/path/libraylib.web.a ./scripts/build-example.sh web
# Or activate an SDK explicitly for this command:
EMSDK=/absolute/path/emsdk RAYLIB_WEB_LIB=/absolute/path/libraylib.web.a \
    ./scripts/build-example.sh web
```

`EMCC` may select a compiler explicitly when paired with `RAYLIB_WEB_LIB`.
Explicit builds bypass Homebrew and the shared raylib cache; keep archive/compiler
versions and Odin raylib bindings compatible. Web compilation and linking finish
in a private directory before outputs replace files in `binaries/web/`.
The HTML host supplies Odin runtime imports alongside
Emscripten's imports; replacing it with a generic Emscripten page is insufficient.

Serve `binaries/web/` through your existing static host with a Wasm MIME type. Final
example outputs belong in `binaries/`; temporary builds, captures and experiments
belong in `.work/`.

### Linked browser smoke check

Use an already installed Chromium-family executable; the runner uses Node's
standard library and Chromium's debugging pipe, with no npm package or browser
download. Supply its executable path through `CHROMIUM_BIN` (default `chromium`):

```sh
CHROMIUM_BIN=/absolute/path/to/chromium ./scripts/check-web.sh
# Include the linked check after the full compiler/spec/test/linter suite:
CHECK_WEB=1 CHROMIUM_BIN=/absolute/path/to/chromium ./scripts/check.sh
```

The same SDK/archive overrides apply. A temporary debug build exports a small
read-only showcase snapshot for precise assertions; ordinary builds omit that
export. The runner serves only that temporary build on an ephemeral loopback
port, launches an isolated headless browser, and checks Wasm startup, actual
pointer click/cancellation, Tab/Shift+Tab through GLFW, focus-loss cancellation,
held-key release, outside HTML controls and browser defaults, UTF-8 editing and
narrow-viewport resizing. Browser errors, failed assertions,
missing dependencies and timeouts fail the command. The browser, server and
scratch files are closed on completion. The default CI job runs the portable
suite, including the maintained capture and host tests; the linked check is
explicit because it additionally needs Emscripten, web raylib and Chromium.
This is a headless runtime check, not graphical playtesting or evidence for
Android/iOS or another browser engine.

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

## Shared dependency management

On this Mac, use Homebrew's Odin installation and its managed LLVM/raylib
dependencies: `brew install odin`. Project launchers prefer that compiler;
explicit compiler overrides remain available for testing exact versions. Other
platforms may use the required official Odin release on `PATH`.
Do not download another compiler bundle into the checkout. Historical exact
nightly binaries are retained once under `~/.local/share/dev-pool/odin/`, with
compatibility links for already captured jobs.

### Compiler vetting policy

Compiler verification uses maximal compatible vetting on first-party packages:
`-vet -vet-tabs -vet-using-param -vet-nil-deref -vet-uninitialized
-vet-atomic-access -strict-style -warnings-as-errors`. Package scopes preserve
vendored dependencies and public APIs. Additional `-vet-unused-procedures`
checks use closed application entry points; attributed test procedures are not
classified as unused, because this compiler incorrectly reports them even under
`odin test`. All other vet checks still cover tests and library code. Keep the
existing targets, collections and defines. Compiler failure prevents shared lint;
report existing findings without weakening the checks.
