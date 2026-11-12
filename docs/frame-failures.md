# Host-owned frame failure handling

A failed frame must never be drawn or used for input. The normal API returns a
failure from `finish_layout`; the compatibility and portable APIs return it from
`finish`. Failed or unfinished geometry supplies no hits or paint operations.
The host decides what to present instead; the library has no application state,
window lifecycle, presentation history or recovery service.

The reference production policy is: retain the last successful frame only while
it still represents current state and viewport and all of its backing data is
valid. Otherwise show a small host-owned error surface and suspend ordinary UI
actions until a successfully finalized successor is presented. The development
showcase deliberately asserts so declaration defects fail immediately.

## Building and publishing a successor

Consume input against the frame actually presented, then apply the resulting
host commands. Build the successor in separate node storage and a separate
presentation allocator. Keep the previous frame untouched until the host either
publishes the complete successor or switches to its error surface.

1. On success, publish the new frame. Its node storage, copied display strings,
   prepared lines and borrowed triggers must stay alive through drawing and the
   next input. The old storage may be reused after its final input and draw have
   finished; asynchronous rendering hosts must also wait for their own completion.
2. On failure, cancel outstanding press/drag capture and pending activations.
   Retain the previous successful frame only if every presentation dependency
   still matches. Valid storage alone is insufficient: a committed command may
   have changed visible values, enabled controls or trigger meaning. A viewport
   change also invalidates old hit geometry.
3. If those conditions do not hold, stop ordinary action dispatch and draw the
   host's error surface. Discard ordinary pointer/key/text events while blocked
   rather than replaying them after recovery. Continue handling host-level close,
   resize, diagnostics and retry operations without consulting stale triggers.
4. Retry when the host's recovery policy allows it. Resume ordinary UI input only
   after a successful replacement has actually been presented. A release from a
   press begun on an older presentation must not activate a recovered control.

A host can use a monotonically increasing presentation revision to detect state
changes. Increment it for all changes that can affect visible content, styles,
fonts, enabled controls or trigger semantics; compare viewport and other geometry
inputs as well. The library does not determine whether two frames represent the
same application state. Do not roll back a committed application command merely
to make old geometry appear current.

Two presentation slots are one small implementation, not a required library
abstraction. Each slot can own a node array and arena. Reclaim only the inactive
slot before building, and switch the presented slot only after `finish` succeeds.
Copying a `UI`/`Frame` struct does not copy its node slice, strings, prepared lines
or borrowed trigger payloads. Keep slot structs in place when their slices or
arenas point into their own backing arrays. Retaining a frame also requires its
borrowed trigger paths/payloads and font/texture resources to remain valid and
semantically current. Separate scratch allocation can be reset independently.

Retaining the previous frame saves visual disruption when state is unchanged,
at the cost of a second presentation's storage and explicit lifetime management.
A simpler host may always use its independent error surface on failure instead.

## Independent error drawing

The fallback must not depend on nodes, measurements or hit regions from the failed
frame. For a raylib host using the normal API, the drawing branch can be as small as
this. `presented` is the retained `Resolved_Layout`; `paint_presentation` is the
host procedure that supplies its retained handles and appearance to `paint_*`:

```odin
rl.BeginDrawing()
rl.ClearBackground(rl.BLACK)
if has_current_presentation {
    paint: ui.Paint
    ui.begin_paint(&paint, presented)
    paint_presentation(&paint)
    ui.end_paint(&paint)
} else {
    rl.DrawText("Unable to display this screen.", 16, 16, 20, rl.WHITE)
}
rl.EndDrawing()
```

A compatibility host can use `ui.draw(&presented)` in the successful branch
instead. The host establishes `has_current_presentation` using the policy above. Keep
ordinary action routing under the same condition; drawing an error message alone
does not disable stale controls. The fallback message and its rendering resources
must be available independently of the failed builder. Record `failure` and
`failure_node` for diagnostics without exposing partial geometry as a presentation.

## Runnable ownership example

[`examples/failure_policy/failure_policy.odin`](../examples/failure_policy/failure_policy.odin)
is a headless host using only the portable layout/input packages and Odin core.
It demonstrates two fixed node arrays, two presentation arenas and caller-owned
press capture. Its seven scenarios assert successful publication, safe retention
after an unchanged-state failure, repeated changed-state failures, recovery,
resize invalidation and recovery at the new viewport. The printed error message
stands in for the independent graphical error branch above.

```sh
./scripts/odin.sh run examples/failure_policy -debug
```

The example injects a node-capacity failure by limiting candidate storage to the
root node. It verifies that retained display text survives candidate/scratch
resets and that stale releases cannot click a replacement. It illustrates layout
failure handling rather than recovery from allocation, renderer or platform
failure. `./scripts/check.sh` runs it natively and checks its Wasm target with the
project's compiler vetting, closed-entry-point unused-procedure checks and shared
linter. It introduces no application-store, persistence or session requirement.
