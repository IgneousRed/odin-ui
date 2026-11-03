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
