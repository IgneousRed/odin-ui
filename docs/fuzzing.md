# Disposable example exploration

The examples expose real replay boundaries for the pinned
[odin-fuzz guide](https://github.com/IgneousRed/odin-fuzz/blob/8e5e8e480a93b3eaa611c8e131341e4edf56c690/GUIDE.md).
The library and source-copy release have no fuzz-tool dependency.

## Setup and run

Use macOS ARM64 with Xcode Command Line Tools (`sandbox-exec`, `nm`) and the
one-time [Nix prerequisite](../README.md#checks-and-showcase):

```sh
./scripts/dev --profile fuzz python3 -I tools/run-odin-fuzz.py --budget 30 --seed 1
```

The optional `fuzz` profile packages published Nix-native odin-fuzz 0.4.0 with the
canonical package recipe and no compatibility patch. The ordinary development
environment omits the fuzzer; it is realized only when this profile is selected.
Direct invocation of the driver outside a project environment selects this profile.
The source declaration and root
[lock](../odin-fuzz.lock.json) must agree. The scanner and matching Odin/LLVM
tools are immutable Nix outputs; there is no consumer source/scanner cache,
Homebrew lookup or tool checkout. The driver reads the immutable environment
manifest, checks its full fuzz revision and exact environment selection against
this checkout, verifies the packaged executables exist, and refuses
tool/compiler/scanner substitutions. Missing or stale packages fail
setup; no executable is selected from an ambient PATH or legacy local cache.
The canonical CLI also fixes its compiler/scanner paths and uses isolated Python.
The driver validates the LLVM major against
`odin report`, runs `scripts/check.sh`, then `doctor`, discovery and the two
configured headless replay examples serially. On Darwin the selected native
backend is LLVM 23.1.6. The packaged scanner builds with that toolchain; runtime
exploration is verified separately. Emscripten's coupled LLVM 24 SDK remains
for web linking.

The driver prints its run directory under `.local/fuzz/`. Retain it with its
metadata, tool/compiler/source/configuration identity, seed, budget and outcomes.
New runs hold the Nix environment via a GC root, preserving replay inputs without
modifying historical captures. Subsequent runs reuse `.local/fuzz/corpus/`.
A zero exit alone is insufficient: **each configured replay** must appear in
`summary.json` with `status=explored`, `coverage_mode=llvm_sancov`, positive
execution and first-party edge counts, and no findings. ASan-only fallback,
missing launches and setup failures cannot satisfy the gate. Bounded exploration
does not establish correctness.

After **`scripts/check.sh` has passed on the same tree and toolchain**, pass
`--skip-checks` to reuse those prerequisite results. All verification runs
locally; no hosted CI is required. The normal suite runs replay seeds without
launching exploration.

## Replay boundaries

All JSON seeds are below 4 KiB and run in their actual native replay
configurations during `scripts/check.sh`. Each application processes at most 256
events from its explicit project-relative filename and exits on EOF/completion.
Malformed JSON, invalid Unicode and out-of-range external values are ordinary
input rejection, never assertions. Input decoding owns a separate arena so
frame scratch resets cannot invalidate pending events.

1. [Showcase UI events](../examples/showcase/events.json) feed the same input,
   editing, layout and painting path as native/web execution. The headless
   build uses CPU-loaded metrics from the same embedded font and observes
   drawing commands without a window or GPU. It checks UTF-8 selection
   boundaries, capture cancellation, clip balance, finite drawing parameters
   and allocation-free painting, without a fixed-size capture array.
2. The showcase accepts the guide's `frame`, `dt`, `keys_down`, `keys_pressed`,
   `mouse`, `viewport`, and `close` fields. Mouse coordinates and touch positions
   are device pixels at scale 1. Time is accumulated from bounded `dt`; no ambient
   clock is read during replay. Optional `text` (a committed string), `blur`, and
   `touches` (unique nonnegative IDs and positions) expose host input that the
   built-in UI generator does not supply. A separate
   [host event seed](../examples/showcase/host-events.json) is read
   before generated UI events and declared as a normal file boundary. This keeps
   text, focus and touch frames independently available to schema-guided mutation;
   a `close` event in either stream ends the combined replay. Mouse right/wheel
   and `frame` are
   accepted metadata; this showcase has no right-click action or scroll control.
3. [Failure-policy events](../examples/failure_policy/events.json) vary
   `revision`, `width`, and `fail` across the existing two-slot presentation
   lifecycle. Assertions check that failed frames cannot hit, retained content
   matches current presentation state, and stale releases cannot activate.
   Ordinary execution still runs the original seven expected-outcome cases;
   the web configuration remains portable.

Headless observation does not test rasterization, GPU resources, browser input,
or mobile platform services. Keep the normal native/Wasm checks and linked web
smoke check. It also does not turn arbitrary mutation of library internals into
a valid caller: storage/handle lifetimes and valid UTF-8 remain API contracts.

## Findings and upgrades

Only **Gemini 4 Neon** (`antigravity` / `gemini-4-neon`) may read upstream
README/docs, run `reproduce`, or inspect detailed `report.md`, `report.json` and
`findings/` bundles. Other models read only the guide, run `doctor`/`scan`/`explore`
and inspect `summary.json`. On exit 1, a positive finding count, or any need for
detailed gap/failure triage, stop and delegate to that exact model. Its response
must contain only files changed, high-level fixes, verification counts and
remaining owner items; no payloads, crash traces or low-level security details.
Keep the run intact for that work. Confirmed fixes should become meaningful
portable regressions and rerun affected checks plus exploration.

For upgrades, select a full published commit, read only its `GUIDE.md`, update
source declaration and lock/archive checksum together, and take the canonical
package recipe from the integration owner. Verify checks, `doctor`,
discovery and real coverage feedback on each configured replay. Do not depend on
unpublished behavior or inspect the implementation.
For the intermittent Odin parser issue, pass
`-thread-count:1` from the first compiler check with all existing flags; do not use a rewriting wrapper or
change compiler policy. `scripts/check.sh -thread-count:1` forwards that explicit
argument directly to its compiler invocations, including the copied consumer;
it does not alter defaults. If an operation is blocked, record it and stop that route.
