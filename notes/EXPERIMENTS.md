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
