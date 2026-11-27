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

Version `0.2.12` is an early release; the API may change before 1.0. Read the
[changelog](CHANGELOG.md) before updating your copy.

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

Install [Nix](https://nixos.org/download/) once. On macOS, also install Xcode
Command Line Tools for system SDKs; exploration requires macOS ARM64. The locked
Darwin development environment requires macOS 26 or later. Linux x86-64 keeps
its existing pinned toolchain. This nixpkgs revision does not support Intel macOS.

From a checkout or extracted repository source archive, run:

```sh
./scripts/dev odin report       # obtain the locked development environment
./scripts/check.sh
./scripts/build-example.sh desktop
./scripts/dev ./.work/build/showcase
```

The entrypoints bootstrap through `scripts/dev`; no sibling checkout, existing
cache, Homebrew installation or personal skill is required. Nix verifies fixed
source hashes and shares immutable compatible tools through its store. Source
staging includes only declared inputs in `nix/source-files`, keeping `.work/`
and generated outputs out of the environment. The launcher retains the selected
closure for each command and keeps the last environment rooted in `.work/nix/`.
Build outputs and disposable working state stay outside the store.

For metadata without realizing tools, use the same staged launcher:
`./scripts/dev --eval packages.aarch64-darwin.dev-environment.drvPath --raw --option allow-import-from-derivation false`.
Avoid direct path-based flake evaluation of a populated workspace; it also
copies ignored working data into the store.

| Tool | Locked version / identity | Declaration |
| --- | --- | --- |
| nixpkgs | `619c39f6eac5d1ed6b8f073a9414baf7034b2356` | `flake.lock` |
| Odin | `dev-2026-11a`, exact source `9a6991685ddf663956d9836602eb421e141fc443`; Darwin LLVM 23.1.6 | `nix/llvm23/`, Linux `nix/toolchain.nix` |
| Shared Odin linter | `0.7.7`, `6cca8868fa34b8ddd291e358ae640571a60c80e4` | `odin-lint.lock.json`, `nix/odin-lint-source.nix` |
| Allium CLI | `3.7.2`, language version 3 | `nix/allium.nix` |
| Native and web raylib | `6.2`, static web OpenGL ES 2 | Darwin `nix/llvm23/`, Linux `nix/toolchain.nix`, `nix/web-raylib.nix` |
| Emscripten | `7.0.1`, matching upstream LLVM 24 and Binaryen | `nix/emscripten-sources.json` |
| Node.js / Python | Node 26.13.1; Darwin Python 3.15.2 rebuilt with LLVM 23.1.6 | `flake.nix`, `nix/llvm23/` and `flake.lock` |
| Darwin browser tools | Playwright `1.65.1`, matching Chromium and native WebKit | `nix/playwright-sources.json` |

The Odin and Emscripten LLVM versions serve different compilers: Darwin LLVM 23
matches Odin's backend and native toolchain; Linux retains LLVM 22. LLVM 24 belongs
to the exact Emscripten 7 SDK and remains coupled to it. Its frontend uses the
selected Python; its internal compiler binaries are preserved.
Linux's linked smoke check uses the Chromium from the shared nixpkgs pin.

Run the complete check suite locally with `./scripts/check.sh`. The default
suite type-checks Wasm and runs headless native tests; `./scripts/check-web.sh`
separately links and runs the browser showcase. The locked Nix environment
passed the full local suite and linked Chromium regression check on macOS ARM64
with Emscripten 7.0.1 and raylib 6.2. Native WebKit startup also passed. Checkout
and source-archive setup use the same declared-input allowlist and pinned tool
definitions. No private records are required for setup or verification.
Library consumers can copy plain sources using [VENDORING.md](VENDORING.md);
Nix is a developer prerequisite for this repository, not a library runtime.

Checks validate shell-script syntax and the shared Allium specification, and run
portable tests and raylib geometry/text tests without opening a window, plus native
and Wasm showcase type checks. Maintained drawing-capture cases exercise caret
visibility, UTF-8 and multiline selections, narrow fields and ordinary button
centering against real raylib measurements. The capture package runs serially
because raylib line spacing is process-global; macOS interposes shared-library
drawing calls and Linux wraps the bundled static archive's drawing symbols.
Node checks execute the actual HTML host's keyboard routing, frame-failure
handling and Odin import forwarding using the locked Node executable. The
standard suite also checks the smoke-build define
with the same compiler vetting as the normal showcase.
Compiler gates follow the [compiler vetting policy](#compiler-vetting-policy).
Run `./scripts/check.sh` after editing code: every applicable Odin compiler check
must pass before all GitHub-pinned shared linter rules run. Setup or analysis
failure is not a pass.
Named regression cases reference the specification's lifecycle, ownership and
measurement invariants; the specification check itself does not execute the Odin
implementation. Checks also package the actual release ZIP, verify its checksum,
extract it into a separate consumer project, run a headless native program and
check the Wasm target using only the copied packages and ordinary Odin commands.
Consumer projects validate their own code and application integration; they do
not invoke this repository’s check suite.

### Disposable input exploration

For optional macOS coverage-guided exploration, use the separate
`scripts/dev --profile fuzz` environment; see [fuzzing](docs/fuzzing.md).
The ordinary development environment does not realize or retain the fuzzer.
The pinned driver checks prerequisites, then runs headless showcase and
failure-policy event streams through the same example/library paths. Replay
seeds run in the normal suite; consumers need no fuzz tool.

### Shared Odin linting

[`odin-lint.lock.json`](odin-lint.lock.json) and
[`nix/odin-lint-source.nix`](nix/odin-lint-source.nix) pin the public
[`IgneousRed/odin-lint`](https://github.com/IgneousRed/odin-lint) source at
`6cca8868fa34b8ddd291e358ae640571a60c80e4` (`0.7.7`). The canonical
[`nix/odin-lint.nix`](nix/odin-lint.nix) builds it with the locked compiler and
stamps that revision into the executable. Update metadata follows published
`main` revisions; the fixed `v0.7.7` tag does not move with later compatible
commits. Environment evaluation rejects a mismatched source/lock pair. No Python/Git runner, mutable linter cache, GitHub
login or token is needed at runtime.

The check script runs library checks and package tests, native and Wasm showcase
checks (including `RAYLIB_WASM_LIB=env.o`), the failure-policy example and the
packaged-source consumer before invoking the installed linter:

```sh
./scripts/dev sh -c '"$ODIN_LINT_BIN" --root . --source-root src --collection odin_ui=src src examples tests'
```

Use `./scripts/check.sh` for verification so the compiler precondition is enforced.
All active rules are mandatory. Exit `0` means clean, `1` means findings, and
`2` means setup/usage/analysis failure. A terminated or incomplete analysis is
never a clean result. The copied-source consumer is compiled separately in
ignored `.work/`; generated copies are not lint inputs. Report unresolved compiler,
analysis and source findings with the exact target/tool revision and the failed
check; do not treat them as a clean result.

Public APIs can have consumers outside this checkout. Repository-local lint
alone cannot justify narrowing visibility or interfaces. See the
[pinned rules and analysis limits](https://github.com/IgneousRed/odin-lint/blob/6cca8868fa34b8ddd291e358ae640571a60c80e4/docs/rules.md).

To upgrade deliberately:

1. Select a published full commit and review its `README.md`,
   `docs/integration.md` and `docs/rules.md` at that exact revision.
2. Stage the fixed source declaration and canonical package expression from the
   integration owner. Update the root lock and source declaration together,
   preserving the compiler checks, targets, collections and defines. Never
   replace a source pin merely because a newer recipe is available.
3. Verify a fresh Nix realization and the binary's `--version`, then run
   `./scripts/check.sh`. Investigate new findings without suppressing rules or
   treating skipped analysis as success. `SIMPLIFY001` remains mandatory; check
   actual bindings and semantic safety before inlining.
4. Review and commit the lock, recipe and integration changes together. Run the
   read-only dependency update check before every commit as described below.

The showcase demonstrates resize, wrapping, buttons, fields, progress and shared
input handling. It is an example host rather than a replacement application shell.
For a runtime smoke check, click the counter, press it and release outside to
confirm cancellation, edit the field (including backspacing over `é`), and resize
to a narrow and a wide viewport. In the browser, move focus away from the canvas
during a press and confirm that releasing does not increment the counter. These
checks exercise the linked host; a successful type check alone does not cover them.

Web builds use the locked Emscripten 7 SDK and the canonical static raylib
archive built with that same SDK:

```sh
./scripts/build-example.sh web
```

The SDK derivation prepares its sysroot/library cache once, then freezes it.
Project builds read that store cache without copying the SDK or sysroot into
`.work/`. A missing cache variant fails explicitly and must be added to the
canonical derivation with its needed flags. The shared raylib recipe preserves
`PLATFORM_WEB`, `STATIC`, OpenGL ES 2, and validates a linked Node smoke program.
Native and web libraries remain separate outputs. There is no host-tool discovery
or automatic mutable SDK fallback.

Web compilation and linking finish in a private directory before outputs replace
files in `.work/build/web/`. The HTML host supplies Odin runtime imports alongside
Emscripten's imports; replacing it with a generic Emscripten page is insufficient.

Serve `.work/build/web/` through your existing static host with a Wasm MIME type. Final
example outputs belong in `.work/build/`. Working material in `.work/` is
disposable; retain necessary replay inputs and local evidence under `.local/`.

### Linked browser smoke check

The environment supplies the locked Chromium executable. The runner uses
Node's standard library and Chromium's debugging pipe:

```sh
./scripts/check-web.sh
# Include the linked check after the compiler/spec/test/linter suite:
CHECK_WEB=1 ./scripts/check.sh
```

A temporary debug build exports a read-only showcase snapshot for assertions;
ordinary builds omit it. The runner serves that build on an ephemeral loopback
port and checks Wasm startup, pointer click/cancellation, Tab/Shift+Tab through
GLFW, focus loss, held-key release, outside HTML controls and browser defaults,
UTF-8 editing and narrow-viewport resizing. Errors, missing dependencies and
timeouts fail the command. Browser, server and scratch files close on completion.
The linked check remains explicit. It is a headless Chromium runtime check;
Android/iOS, rasterized visual output and WebKit behavior need separate coverage.
The shared Darwin browser package also supplies matching Playwright/WebKit to
consumers that already test those engines; Odin UI does not add another runtime
suite merely because those artifacts are packaged.

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

No general external-review gate is configured; the local checks above remain
required.

## Maintaining releases

Repository development builds use `scripts/odin.sh`, which registers this
checkout's `src/` as the `odin_ui` collection. Consumers do not need this helper.

Every new push to `main` must become GitHub's latest public release for that
exact commit. Advance the version when the current version is already published;
preserve clean tags/assets, but sanitize affected history after visibility changes.
Update `VERSION` (version,
source and tagged release URL), `VENDORING.md` and `CHANGELOG.md`, then run:

```sh
./scripts/precommit
```

The check builds the source-copy ZIP in `.work/package/`, verifies its checksum and
exercises that exact archive in a separate native/Wasm consumer. It contains one
`odin_ui/` folder ready to copy. Packaging prepares and validates a new archive
privately before replacing the previous ZIP, and produces
`.work/package/SHA256SUMS.txt`.

Commit the checked changes on `main`, tag that commit and push only the explicit
main/release-tag refs. Never mirror-push or push all local refs. The publication
hook validates the outgoing tips and their ancestry; local recovery is not a
publication input. Write
`.work/package/release-notes.md` with local verification and any limitations. Publish
with both artifacts and explicitly select latest; a draft can hold the uploads
until they are complete:

```sh
version=$(head -n 1 VERSION)
gh release create "v$version" ".work/package/odin_ui-v$version.zip" \
    .work/package/SHA256SUMS.txt --verify-tag --draft \
    --title "Odin UI v$version" --notes-file .work/package/release-notes.md
gh release edit "v$version" --draft=false --latest
```

Before considering the main push complete, verify the public latest release, its
tag's exact commit, and the downloaded assets against their checksum. Publication
uses local verification and has no GitHub Actions prerequisite. GitHub also
supplies full repository source archives; those include the tests and showcase.
When material becomes private or local-only, removing it only at HEAD is
insufficient: audit and sanitize affected published branches/tags and artifacts,
coordinate pinned consumers, and verify replacements before claiming completion.
Instruction files are private and excluded at every public path depth. Public
setup and documentation are self-contained; local instructions are not inputs.

## Shared dependency management

`flake.lock` and the fixed recipes in `nix/` select tools. Darwin's canonical
Git 2.56.1 shares the rebuilt Python and selected Perl 5.44.0 module scope; native
library choices and compatibility holds are recorded in
[the bundle notes](nix/llvm23/README.md#shared-dependency-selection).
Node 26.13.1 keeps the existing shared catalog output, rather than realizing the
native bundle's optional Node override merely to converge support libraries.
Update locks only as an explicit reviewed change. After cloning, enable the dependency-check hook
with `git config core.hooksPath .githooks`. Source archives can run the check
commands directly. Before **every commit**, run:

```sh
./scripts/precommit
# Read-only update report alone:
./scripts/check-deps
```

`precommit` checks for newer dependencies, reports available updates without
changing locks, then runs the normal checks. Network/metadata failures are
failures, not evidence that everything is current. Update metadata is derived
from the authoritative declarations in `flake.nix` and installed into the
immutable environment. The checker prefers the rebuilt Python when already
realized, otherwise uses the pinned public bootstrap interpreter without source
builds. A successful report switches its cache root to the interpreter actually
used. New retained executable captures under `.local/` hold their environment with
`scripts/retain-nix-environment`. Reusable fuzz data belongs in `.local/fuzz/`;
`.private/`, `.local/`, `.work/` and fetched `.vendor/` material are excluded from
publication. Tools use shared immutable store outputs; no checkout cache is needed. Generated
outputs are disposable; remove package staging after verified publication.

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
