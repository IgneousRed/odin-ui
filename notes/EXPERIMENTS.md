# Simplification experiments

## 2026-11-02 coding-skill cleanup

Baseline: commit `9e98e56d6f485b40987f19a95bde49fd1de8789f`, Odin
`dev-2026-10:84bc3fc21`, macOS ARM64. Original and candidate packages were compiled
in the same comparison executable with distinct package namespaces. These are
focused headless checks, not graphical runtime or general performance claims.

Kept one-buffer whitespace normalization and truncation: 1,210 combinations of
empty text, Unicode codepoints/whitespace, explicit blank lines, long words and
widths 0–120 produced the same wrapping/truncation results as the baseline.
Whole-candidate measurement is preserved, including kerning-sensitive suffixes.
For a 1,000-byte input consisting of 500 repetitions of `a `, wrapping at width
10,000 and truncation at width 5,000, a monospace callback and tracking allocator
recorded 1,000 allocations / 376,388 bytes before and 3 allocations / 2,131 bytes
after. This measures portable text buffers; raylib measurement still decodes
candidate strings separately.

Kept flat parent-before-child positioning: 500 deterministic mixed trees combining
nested horizontal/vertical groups, fixed/fit/grow sizes, alignment, padding, gaps,
scroll offsets and clipping produced identical measured sizes, rectangles, clips
and scroll extents. Construction-only link removal reduced raylib node size from
288 to 272 bytes. Caller-provided storage additionally removes node allocation
from the showcase frame loop.

Tried a hybrid layout with geometry nodes and separate payload/trigger columns.
It also matched the 500 trees, but added allocations and buffer-capacity/lifetime
coordination and changed public payload/trigger access. The library and callers
were simpler with one node slice; retain the hybrid as a profiling-driven proposal
rather than extending the API around parallel storage without workload evidence.

Rejected flat reverse-order measurement: it matched geometry, but serving a
subtree `measure_width` query by scanning all subsequent nodes did unnecessary
work. With 1,023 sibling leaves, 2,000 first-leaf queries took about 43 microseconds
with recursive subtree measurement and 44 milliseconds with the candidate in an
unoptimized local probe. Keep subtree measurement recursive; flat positioning
needs no such extra scan or traversal index.

Kept explicit device sampling plus a portable pointer transition. Touch reordering,
missing capture, last-touch release, focus loss and DPI conversion can now be
checked without raylib polling. Kept caller-owned mutable Press/Scroll APIs: private
working-data mutation is allowed, and returning replacement state would add caller
bookkeeping without removing a library-owned store (there is none).

Kept strict web symbol checking with explicit forwarding of the two required Odin
runtime imports. Linked the showcase with Emscripten 6.0.13 and web raylib 6.2;
this does not establish browser rendering/input correctness. Injecting a failing
ZIP command also confirmed packaging failure preserves the previous archive and
checksum file. The font binary matched the manifest's pinned upstream source.

## 2026-11-02 sol-finish validation

Three simplification passes and three separate bug reviews covered layout/input,
text/raylib, and showcase/release tooling, followed by integration review.
The layout differential probe matched the prior commit across 10,000 generated
nested trees, including caller-storage reuse. The bug review found and fixed
extreme-scale rounded-hit and drag-threshold comparisons by widening their
distance calculations before squaring.

Multiline field selection and caret drawing now use line-local coordinates.
Ten headless draw-capture cases checked second-line and reversed selections,
multi-line highlights, UTF-8 offsets, trailing and blank lines, empty fields,
single-line fields and custom raylib line spacing. These capture actual drawing
commands without a window or GPU; they do not establish graphical runtime
correctness. The complete check suite passed 46 tests plus specification,
native/Wasm compiler and packaged-consumer checks; the desktop showcase built.

Upstream release metadata matched all existing pins: Odin `dev-2026-10`, Allium
`3.6.1`, raylib `6.2`, Emscripten `6.0.13` and actions/checkout `v7.0.1`.
No dependency changes were needed. Packaging failure probes preserved previous
outputs through ZIP creation, ZIP validation and checksum generation failures.
The two final file moves do not publish an atomic ZIP/checksum pair; a failure
there stops the consumer check, and checksum verification rejects a stale pair.

## 2026-11-03 coding-skill audit

Audited the tracked implementation, hosts, tests, specification, scripts, CI,
documentation and project records from clean commit
`f6018a2c13c30376a77244e3f2f4a9e3f575309e` against the installed Coding skill and
AGENTS.md. The skill's prescribed source-role folders and initial project records
apply to new projects; they do not require restructuring this existing library.
The project's explicit exclusion of application stores, persistence, migration
and recovery applies. Caller-owned capture state, borrowed triggers, node storage
and presentation/scratch lifetimes remain subject to the documented contracts.

Retained the portable layout/text/input packages and raylib I/O boundary. Frames
use indexed relationships and reconstructible geometry/text preparation, with
caller-selected allocators and reusable node storage. The earlier SoA experiment
already records its API/maintenance cost; this audit found no new workload evidence
to justify that change. No dependencies, external database schemas or vendored
assets changed. Existing unrelated scratch/recovery artifacts were preserved.

Fixed a narrow field emitting a negative-width underline: a headless capture of
actual drawing calls reproduced width `-1.5` for a field of width `1` at text size
`10`. The same probe passed widths `0`, `1`, `2.5`, `4` and `100` after the fix.
Ten multiline/UTF-8 field-overlay capture cases also passed, with empty and
newline-only fields now correctly omitting their zero-width underline. These
are boundary-call checks using the existing raylib shared library, not GPU or
graphical interaction evidence. The capture setup must select `RAYLIB_SHARED=true`;
static linking conflicts with the replacement drawing symbols.

The complete standard suite passed all 46 tests, Allium validation, native/Wasm
compiler `-vet` checks and the packaged-source consumer run/check. Shell syntax
validation now runs in that suite. Both debug showcases built, including the web
link with the existing Emscripten 6.0.13 and raylib 6.2 installations. Node syntax
checks passed for the JS library and inline HTML script. The font binary matched
its manifest SHA-256. No graphical playtest or cross-platform runtime claim is
made by this audit. Separate linter selection and external-review policy remain
open in TODO.md; neither a new dependency nor an external-review gate was assumed.

## 2026-11-03 sol-finish validation

Three `gpt-6.1-sol` agents at high reasoning effort reviewed and simplified the
portable core, raylib adapter, and showcase/tooling/docs. Three fresh agents then
reviewed those same boundaries for bugs, followed by parent intersection review.
Kept the compact package and script boundaries. Removed repeated checks already
established by touch cancellation, UTF-8 boundary clamping and successful drawing
clips; retained the independent inset-border and narrow-field underline guards.
The portable reviewer compared 61 UTF-8 boundary cases and 240 pointer snapshots
with the previous expressions; every result matched.

The raylib bug review reproduced unbounded rounded-control tessellation: a valid
oversized button clipped to a 100-by-100 viewport supplied 1,250,000,001 segments
at text size `1e10`, and a larger value converted to a negative segment count.
Scissoring limits rasterization, but raylib still loops through the requested
segments on the CPU. Cap the count at 128 before integer conversion for both fill
and border. Ordinary controls keep their existing count; very large corners trade
additional tessellation detail for bounded work. Ten draw-capture cases from text
size `10` through `1e30` passed explicit expected counts after the fix.

Official upstream metadata still matched the existing [Odin dev-2026-10](https://github.com/odin-lang/Odin/releases/tag/dev-2026-10),
[Allium 3.6.1](https://github.com/juxt/allium-tools/releases/tag/v3.6.1),
[raylib 6.2](https://github.com/raysan5/raylib/releases/tag/6.2),
[Emscripten 6.0.13](https://raw.githubusercontent.com/emscripten-core/emsdk/main/emscripten-releases-tags.json),
and [checkout v7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1)
pins. The CI archive digests and checkout commit matched upstream metadata, and
the current upstream font binary matched the vendored SHA-256. No dependency
update or permission request was necessary.

Final combined verification passed the complete 46-test suite, shell syntax,
Allium contract validation, native/Wasm compiler `-vet` checks and packaged-source
consumer execution/check. Both desktop and web debug showcases built. All 25
focused drawing captures passed (five narrow fields, ten field overlays and ten
tessellation limits); the JS library and inline HTML script passed Node syntax
checks. These results establish local build and headless behavior, not graphical
playtesting or execution of the Ubuntu CI job. No separate linter is configured;
its selection and the general external-review policy remain open in TODO.md.


## 2026-11-08 two-loop sol-finish organization review

Completed exactly two review/fix loops, using three fresh `gpt-6.1-sol` reviewers
at high reasoning effort in each loop. The first loop divided implementation and
review between portable layout/input, raylib/text, and showcase/UI; the parent
organized tests and records. The second loop independently reviewed the complete
result for simplification, bugs, and UI/platform behavior. The requested lint-fix
confidence threshold changed from 99% to 90% during this task; explicit analyzer,
visibility and inlining exclusions remained in force. No additional loop ran.

Added the required kind/visibility/import sections, grouped imports, and reordered
only confirmed same-section declaration dependencies. Moved the raylib adapter's
public pointer/hit declarations unchanged into its interface and removed their
empty helper. Tests now use distinct `input_tests`, `layout_tests`, `text_tests`
and `raylib_tests` package/directory names with one interface each; this avoids
colliding with the library packages they import. Public test declarations and all
56 tests/assertions remain intact. Independent complete-declaration comparisons
preserved all 147 library declarations and 61 test declarations, allowing only
test import-alias normalization and deduplicated imports. All distributed public
library APIs, fields, defaults, visibility attributes, declaration bodies, native
and Wasm build conditions, JS/HTML and font assets are preserved.

Loop 2 found one small tooling bug: copied-source consumer checks ignored the
selected `ODIN` compiler. They now use `"${ODIN:-odin}"` for both ordinary compiler
commands with the existing flags. A forwarding-compiler probe verified both the
native `run` and Wasm `check` use the selected executable. This does not add a
library helper or collection mapping to the independent consumer.

Version metadata is 0.1.2. Upstream dependency checks found the existing required
Odin dev-2026-11a, Allium 3.6.1, raylib 6.2 and checkout v7.0.1 already current;
no dependencies were added or updated. The shared linter lock and copied runner
remain byte-identical to the captured task baseline, pinned to full commit
`289dc4e0812f108296143f60ac9e1136eec76d17` (0.3.0).

The unfiltered baseline audit contained 680 findings: SECTION003 275, FLOW001 279,
FILE004 73, IMPORT001 24, FILE002 12, FILE003 4, VIS002 11 and SIMPLIFY001 2.
After organization the unchanged linter reports 25: SECTION003 1, FILE002 1,
FILE004 10, VIS002 11 and SIMPLIFY001 2. No rule disables, filtering, compiler-gate
removal or assertion weakening was used. All eleven visibility suggestions and
both useful `padding_valid`/`position` boundaries remain deferred.

The remaining organization findings are deliberately not disguised as fixes:

1. `DEPTH_CAPACITY :: #config(UI_DEPTH_CAPACITY, 32)` is a public integer constant
   correctly placed in Constants/Public. Its use as a fixed-array length causes
   0.3.0 to misclassify its declaration kind and emit SECTION003. An isolated
   compiler-valid `LENGTH`/`[LENGTH]int` probe reproduces the finding; replacing
   only the array use with `[32]int` makes the control clean. Moving the constant
   to Types or hardcoding the production array would be incorrect.
2. `src/raylib` must declare `package raylib_ui`: renaming it to `raylib` produces
   a compiler package-uniqueness error against `vendor:raylib`, which uses package
   names for ABI link prefixes. The directory/import path and unaliased import
   namespace remain `raylib`; no consumer import/API change is needed. FILE002
   does not account for this compiler-required namespace distinction.
3. Ten public native/web declarations remain in their original platform files.
   Unconditional web-only imports fail native `-vet`, and Odin rejects imports
   inside `when`, explicitly recommending file suffixes or build tags. Moving
   everything into one interface would require new aliases/wrappers or changing
   platform/visibility structure. These are genuine source-layout conflicts with
   the rule's representation, not a proved analyzer implementation bug.

Compiler and Allium checks, 56 Odin tests, six existing shared-toolchain Python
tests from pre-existing uncommitted shared-toolchain work, and copied native/Wasm
consumer checks pass. Those unrelated shared-toolchain changes remain excluded
from this task commit; the separately exported commit tree passes its 56-test
compiler/spec/consumer stages before reporting the same 25 lint findings.
The full required command
`./scripts/check.sh` still exits 1 on the 25 records above; it is not a clean or
fully verified result. Setup/analysis failure is never treated as a pass. UI
review was source-level and headless/compiler/link evidence; no graphical
playtest or browser-runtime claim is made.

Detailed reviewer reports, reduced cases, exact compiler errors, complete
unfiltered before/after diagnostics, build/verification logs and declaration
comparison evidence are retained in
`.work/sol-finish-2loops-4qvb22np/`. Shared linter implementation bugs are reserved
for the subsequent linter reanalysis; no sibling project was edited.


## 2026-11-09 sol-finish 0.1.3

Two review/fix rounds used three fresh `gpt-6.1-sol` reviewers at high reasoning
effort per round, covering bugs, simplification and UI/platform behavior. Reviewers
exchanged findings directly; the parent implemented the fixes. Kept the existing
portable packages, raylib boundary, caller-owned state, public APIs, package ABI
name and native/Wasm selection. No broader representation refactor was justified.

Reproduced a clipped field caret with captured raylib drawing calls: twenty
10-pixel glyphs in a 100-pixel field placed the end caret at x=150. Fields now
derive a shared horizontal origin from their selection cursor position, keeping
text, highlights and the caret aligned without new persistent state. Caret
visibility can blink independently. Eleven focused cases cover endpoints, middle
positions, reversed selections, UTF-8, multiline values, empty input and widths
of 100, 2 and 1; ordinary buttons retain centered labels. Ten previous multiline
field-overlay capture cases still pass. These are headless drawing-call checks,
not GPU or graphical playtesting evidence.

The web host lets Tab and Shift+Tab retain browser navigation. Removing only the
canvas handler's cancellation was insufficient because the generated GLFW window
capture handler also prevents Tab. A host capture handler registered before GLFW
now bypasses that callback for Tab on the canvas, without cancelling the browser
default. A Node event-dispatch harness exercises the actual generated GLFW
handler, both Tab directions, unrelated targets and the retained editing keys.
Inline host, JS library and generated JS syntax checks pass. Both debug showcases
build, including the linked Wasm host. No browser runtime claim is made.

The shared linter remains at published 0.7.0, full GitHub commit
`ee48a3d2e473902d9eb16d1d074e259d058abaa1`, with the byte-exact copied runner.
All 27 active rules run without suppression. The full working-tree check passes
56 Odin tests, six independent Python toolchain tests, Allium, native/Wasm compiler
gates and the packaged-source consumer, then reports zero lint findings. An
earlier attempt segfaulted inside the unchanged Odin compiler during the portable
Wasm text check (exit 139); it never reached lint. Its raw log is preserved. The
subsequent full check passed the same compiler flags and configurations.

Version metadata and the packaged installation guide are 0.1.3. The selected
commit tree, exported separately without unrelated shared-toolchain edits, also
passes the complete compiler/spec/56-test/consumer/linter command, including a
fresh GitHub linter bootstrap. Those pending toolchain files and their mixed
README/check-script hunks stay outside the commit.

Dependency metadata still selects Odin dev-2026-11a, Allium 3.6.1, raylib 6.2,
checkout v7.0.1 and shared lint 0.7.0. Emscripten 7.0.0 exists upstream, but the
configured Homebrew formula and installed managed toolchain remain 6.0.13 with
no formula update. No parallel toolchain or new dependency was installed.

Exact commands, before/final logs (including failed attempts), reviewer findings,
headless probes, selected-tree verification and source snapshots are retained
under `.work/sol-finish-fl90z7fc/`.


## 2026-11-12 maintained regression and web checks

Promoted the earlier field-capture probes into `tests/draw_tests`, using Odin
exports to intercept drawing while retaining real raylib text measurement.
The two tests retain eleven caret/blink cases, ten multiline overlay cases and
ordinary button centering. macOS uses shared-library interposition; Linux uses
static-link symbol wrapping. Tests serialize raylib's global line-spacing state.
The standard runner now also executes maintained Node host-event/import checks
and five explicit/default web-toolchain resolver tests alongside the six existing
shared-cache tests. Compiler gates include the temporary smoke-build define.

The shared Homebrew web dependency path remains the default. Explicit
`EMSDK`/`EMCC` plus `RAYLIB_WEB_LIB` selections bypass Homebrew/cache resolution.
Web link outputs are prepared privately. `scripts/check-web.sh` builds into a
temporary directory and runs the actual host in an isolated installed Chromium
through its debugging pipe, without npm packages or browser installation.
Smoke inspection exports are absent from ordinary web builds.

Validation: `CHECK_WEB=1 ./scripts/check.sh` with explicit local Node/Chromium
executable paths passed all compiler targets/defines, Allium, 58 Odin tests,
11 Python tests, Node host checks, the packaged native/Wasm consumer and every
rule of the unchanged GitHub-pinned shared linter. The linked Chromium check
passed startup, real click/outside-release cancellation, Tab/Shift+Tab from the
canvas, focus-loss cancellation, UTF-8 deletion/insertion/navigation and narrow
resize. Missing-browser setup fails with actionable guidance and cleans up.
Normal desktop and explicit-archive web debug builds passed; Wasm export
inspection confirms the normal artifact omits `ui_smoke_snapshot`.
Linux draw-capture sources pass maximal compiler type checks; Linux runtime/CI
execution and graphical playtesting were not performed. No library public API
or production failure-presentation policy changed.

Commands and logs for this work are retained under `.work/todo-cleanup/`.


## 2026-11-12 host-owned frame failure policy

Resolved the specification's production successor-failure question with a
reference host policy in `docs/frame-failures.md`, linked from the ownership
contract. Retention requires valid backing/borrowed data and current state plus
viewport correspondence. Otherwise the host cancels capture, suspends ordinary
UI actions and draws an independent error surface until a valid successor is
presented. The development showcase keeps its fail-fast assertion.

The portable `examples/failure_policy` program demonstrates two caller-owned
node arrays and presentation arenas, independent scratch reset and capture
cancellation. Seven asserted scenarios cover successful publication, unchanged
state retention, repeated changed-state failures, recovery, viewport invalidation
and recovery at the new viewport. Its console fallback stands in for the guide's
raylib error-drawing branch. No persistent application store, library session,
state rollback or new public API was introduced.

`NODE=/opt/homebrew/bin/node ./scripts/check.sh` passes Allium, all native/Wasm
compiler gates including the new example and its closed-entry-point unused
checks, 58 Odin tests, 11 Python tests, Node host checks, the packaged consumer
and every unchanged GitHub-pinned shared lint rule. The example also ran directly
under maximal scoped vetting. Logs are under `.work/frame-failures/`.

During final review after that successful check, concurrent edits appeared in
`src/raylib/raylib.odin` and `tests/consumer/main.odin`. This task did not edit
those files. The recorded pass does not certify those newly changed sources;
the final broad whitespace check also found a new EOF blank line in the adapter.
The policy/example/documentation diff itself passes whitespace checks.


## 2026-11-12 sol-finish review of two-pass follow-ups

Six `gpt-6.1-sol` high-reasoning reviews covered simplification, bugs and UI in
two cohorts, exchanging findings directly. The follow-up review settled after
small cache-metadata and documentation fixes. Shared portable hit testing,
scissor validation and scrollbar bounds replace duplicated adapter calculations;
public APIs remain available. Full-string paragraph measurement is retained
because it also validates intrinsic measurements before wrapping.

The linked Chromium reproduction established that Enter on an outside HTML
button also activated the canvas counter. The host now scopes GLFW keyboard
listeners to its canvas and releases held keys on canvas blur; the showcase also
checks actual focus before keyboard input and focus/caret appearance. Maintained
checks cover outside button activation, typing, Backspace, Tab, held-Shift blur,
canvas pointer cancellation, UTF-8 editing and resize. A malformed JSON cache
record now triggers rebuilding instead of an uncaught TypeError.

Reviewed and updated the shared linter to commit
`949293b8a7fcff8f72927b5afb5c5ada8b2df896` (0.7.1), including the exact upstream
runner and synchronized lock/documentation. Odin dev-2026-11a, Allium 3.6.1 and
the recorded showcase font revision remain current. No machine-wide compiler or
browser installation was performed.

`CHECK_WEB=1 CHROMIUM_BIN=<installed Chromium> ./scripts/check.sh` passed all
native/Wasm compiler targets and defines, Allium, 63 Odin tests, 12 Python tests,
Node host checks, the packaged native/Wasm consumer, every pinned shared lint
rule and linked Chromium runtime checks. The first full attempt stopped at an
Odin compiler segmentation fault during the copied consumer; a focused retry
and the subsequent complete run passed. Compiler failure correctly prevented
lint in the failed attempt. Logs and the reproduction are under
`.work/sol-finish-*.log` and `.work/sol-finish-focus-web/`.

No timings were used to infer speed: background workloads make those comparisons
invalid. GitHub Actions credentials and checked release gating remain explicitly
deferred in TODO.md. Version 0.2.1 is prepared locally; no new release is claimed
without remote verification.
