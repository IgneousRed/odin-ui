package input

// -------------------------------- Imports --------------------------------

// ---------------- Project ----------------

import layout "../layout"

// -------------------------------- Constants --------------------------------

// ---------------- Public ----------------

DRAG_THRESHOLD :: f32(8)

// -------------------------------- Types --------------------------------

// ---------------- Public ----------------

Scroll :: struct {press: Press, origin_offset: f32}

Press :: struct {active, dragging: bool, pointer_id: int, origin: layout.Vec2}

Pointer :: struct {
	position: layout.Vec2,
	pressed, down, released, cancelled: bool,
	id: int,
}

Touch :: struct {id: int, position: layout.Vec2}

Viewport :: struct {
	width, height: f32,
	scale: f32,
	insets: layout.Padding,
}

Result :: struct {pressed, held, released, clicked, dragging: bool}

// -------------------------------- Procedures --------------------------------

// ---------------- Public ----------------

scroll :: proc(state: ^Scroll, pointer: Pointer, inside: bool, current, maximum, wheel: f32, horizontal: bool = false, drag_threshold: f32 = DRAG_THRESHOLD) -> (offset: f32, dragging: bool) {
	limit := max(0, maximum)
	// A changed content extent may leave the caller's old offset outside the range.
	offset = clamp(current, 0, limit)
	// Keep the old origin through release; button clears its capture on release.
	origin := state.press.origin
	event := button(&state.press, pointer, inside, drag_threshold)
	if event.pressed {state.origin_offset = offset; origin = pointer.position}
	if inside {offset += wheel}
	if event.dragging {
		delta := pointer.position.x - origin.x if horizontal else pointer.position.y - origin.y
		offset = state.origin_offset - delta
	}
	return clamp(offset, 0, limit), event.dragging
}

// Capture belongs to the caller, so multiple windows and simultaneous pointers are independent.
button :: proc(state: ^Press, pointer: Pointer, inside: bool, drag_threshold: f32 = DRAG_THRESHOLD) -> Result {
	result: Result
	if pointer.cancelled && state.active && state.pointer_id == pointer.id {state^ = {}; return result}
	if pointer.pressed && inside && !state.active {
		state^ = {active = true, pointer_id = pointer.id, origin = pointer.position}
		result.pressed = true
	}
	if !state.active || state.pointer_id != pointer.id {return result}
	// Widen before subtraction and squaring to preserve finite f32 thresholds.
	dx := f64(pointer.position.x) - f64(state.origin.x)
	dy := f64(pointer.position.y) - f64(state.origin.y)
	if dx * dx + dy * dy >= f64(drag_threshold) * f64(drag_threshold) {state.dragging = true}
	result.held, result.dragging = pointer.down, state.dragging
	if pointer.released {
		result.released = true
		result.clicked = inside && !state.dragging
		state^ = {}
	}
	return result
}

// Mouse ID is -1; touch IDs are nonnegative. Positions enter in device pixels.
// Polling belongs to the adapter; capture continuity and coordinate conversion are pure.
pointer :: proc(previous, mouse: Pointer, touches: []Touch = nil, focused: bool = true, scale: f32 = 1) -> Pointer {
	if !focused {return {id = previous.id, position = previous.position, cancelled = previous.down}}
	if len(touches) > 0 {
		selected := touches[0]
		for touch in touches {
			if touch.id == previous.id {selected = touch; break}
		}
		if previous.down && selected.id != previous.id {return {id = previous.id, position = previous.position, cancelled = true}}
		return {position = logical_position({scale = scale}, selected.position), id = selected.id,
				pressed = !previous.down, down = true}
	}
	if previous.down && previous.id >= 0 {return {id = previous.id, position = previous.position, released = true}}
	result := mouse
	result.id = -1
	result.position = logical_position({scale = scale}, mouse.position)
	return result
}

// Shared logical coordinates; adapters supply device pixels and platform insets.
logical_position :: proc(viewport: Viewport, pixels: layout.Vec2) -> layout.Vec2 {
	scale := viewport.scale if viewport.scale > 0 else 1
	return {pixels.x / scale, pixels.y / scale}
}

content_bounds :: proc(viewport: Viewport) -> layout.Rect {
	return {viewport.insets.left, viewport.insets.top,
		max(0, viewport.width - viewport.insets.left - viewport.insets.right),
		max(0, viewport.height - viewport.insets.top - viewport.insets.bottom)}
}

focus_next :: proc(current: int, enabled: []int, backwards: bool = false) -> int {
	if len(enabled) == 0 {return -1}
	for id, index in enabled {
		if id == current {return enabled[(index + len(enabled) - 1) % len(enabled)] if backwards else enabled[(index + 1) % len(enabled)]}
	}
	return enabled[len(enabled) - 1] if backwards else enabled[0]
}
