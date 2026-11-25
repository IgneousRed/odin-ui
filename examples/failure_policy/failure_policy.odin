package failure_policy

// -------------------------------- Imports --------------------------------

// ---------------- Odin ----------------

import "core:fmt"
import "core:mem"

// ---------------- Project ----------------

import layout "odin_ui:layout"
import input "odin_ui:input"

// -------------------------------- Constants --------------------------------

// ---------------- File ----------------

@(private="file")
NODE_CAPACITY :: 2

@(private="file")
TEXT_CAPACITY :: 4096

// -------------------------------- Types --------------------------------

// ---------------- Public ----------------

Failure_Event :: struct {revision: int, width: f32, fail: bool}

// ---------------- File ----------------

@(private="file")
Outcome :: enum {fresh, retained, error}

// Keep slots in place after initialization: frames and arenas borrow their arrays.
@(private="file")
Slot :: struct {
	frame: layout.Frame(string, u32),
	nodes: [NODE_CAPACITY]layout.Node(string, u32),
	arena: mem.Arena,
	text_storage: [TEXT_CAPACITY]u8,
	revision: int,
}

// -------------------------------- Procedures --------------------------------

// ---------------- Public ----------------

run_cases :: proc(events: []Failure_Event = nil) {
	slots: [2]Slot
	for &slot in slots {mem.arena_init(&slot.arena, slot.text_storage[:])}
	defer {for &slot in slots {free_all(mem.arena_allocator(&slot.arena))}}
	presented := -1
	press: input.Press
	cases := []Failure_Event{
		{0, 320, false}, {0, 320, true}, {1, 320, true}, {1, 320, true},
		{1, 320, false}, {1, 640, true}, {1, 640, false},
	}
	expected := [7]Outcome{.fresh, .retained, .error, .error, .fresh, .error, .fresh}
	if events != nil {cases = events}
	for scenario, case_index in cases {
		// The host has already applied a command or resize. Revision covers all
		// visible state and trigger meaning; viewport changes are checked separately.
		candidate := 1 - presented if presented >= 0 else 0
		slot := &slots[candidate]
		allocator := mem.arena_allocator(&slot.arena)
		// Only the non-presented slot may be reclaimed or overwritten.
		free_all(allocator)
		capacity := 1 if scenario.fail else len(slot.nodes)
		layout.begin(&slot.frame, scenario.width, 200, {}, allocator, slot.nodes[:capacity])
		node := layout.leaf(&slot.frame, {width = layout.grow(), height = layout.grow()})
		if node >= 0 {
			slot.frame.nodes[node].content = fmt.aprintf("Revision %d", scenario.revision, allocator = allocator)
			layout.action(&slot.frame, node, {path = "increment"})
		}
		failure := layout.finish(&slot.frame)
		outcome := Outcome.error
		// Publication and failure both cancel this example's outstanding press;
		// a later release must not activate a control from another presentation.
		press = {}
		if failure == nil {
			slot.revision = scenario.revision
			presented = candidate
			outcome = .fresh
		} else if presented >= 0 && slots[presented].revision == scenario.revision &&
			slots[presented].frame.viewport.width == scenario.width &&
			slots[presented].frame.viewport.height == 200 {
			outcome = .retained
		} else {
			// Discard the old presentation even though its storage is still intact:
			// it no longer describes current application state or viewport geometry.
			presented = -1
		}
		if events == nil {assert(outcome == expected[case_index])}
		if failure != nil {assert(layout.hit(&slot.frame, {10, 10}) == {})}
		// Scratch can be reclaimed independently of both presentation arenas.
		free_all(context.temp_allocator)
		if presented < 0 {
			assert(!press.active)
			// A graphical host draws its own fixed error surface here, without
			// consulting failed geometry or routing ordinary application actions.
			fmt.println("Unable to display UI. Ordinary actions are disabled.")
			continue
		}
		visible := &slots[presented].frame
		assert(visible.resolved && visible.failure == nil)
		assert(visible.nodes[1].content == fmt.tprintf("Revision %d", scenario.revision))
		fmt.println(outcome, visible.nodes[1].content)
		// This is the next input against the presentation just shown. Error mode
		// never reaches hit testing. A release from a prior press is ignored.
		trigger := layout.hit(visible, {scenario.width / 2, 100})
		inside := trigger.path == "increment"
		assert(inside == (scenario.width > 0))
		assert(!input.button(&press, {released = true}, inside).clicked)
		input.button(&press, {pressed = true, down = true}, inside)
		assert(press.active == inside)
	}
}
