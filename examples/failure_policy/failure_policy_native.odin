#+build !js
package failure_policy

// -------------------------------- Imports --------------------------------

// ---------------- Odin ----------------

import "core:encoding/json"
import "core:math"
import vmem "core:mem/virtual"
import "core:os"

// -------------------------------- Procedures --------------------------------

// ---------------- Public ----------------

main :: proc() {
	if !#config(UI_REPLAY, false) {run_cases(); return}
	arena: vmem.Arena
	if vmem.arena_init_growing(&arena) != nil {return}
	defer vmem.arena_destroy(&arena)
	allocator := vmem.arena_allocator(&arena)
	data, error := os.read_entire_file("examples/failure_policy/events.json", allocator)
	if error != nil || len(data) > 4096 {return}
	events: []Failure_Event
	if json.unmarshal(data, &events, allocator = allocator) != nil || len(events) > 256 {return}
	for event in events {
		if math.is_nan(event.width) || math.is_inf(event.width) || event.width < 0 || event.width > 16384 {return}
	}
	// Empty and malformed input never falls back to the built-in demonstration.
	if len(events) > 0 {run_cases(events)}
}
