package input

import layout "../layout"

Pointer :: struct {
    position: layout.Vec2,
    pressed, down, released, cancelled: bool,
    id: int,
}

Viewport :: struct {
    width, height: f32,
    scale: f32,
    insets: layout.Padding,
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

Press :: struct {active, dragging: bool, pointer_id: int, origin: layout.Vec2}
Result :: struct {pressed, held, released, clicked, dragging: bool}

// Capture belongs to the caller, so multiple windows and simultaneous pointers are independent.
button :: proc(state: ^Press, pointer: Pointer, inside: bool, drag_threshold: f32 = 8) -> Result {
    result: Result
    if pointer.cancelled && state.active && state.pointer_id == pointer.id {state^ = {}; return result}
    if pointer.pressed && inside && !state.active {
        state^ = {active = true, pointer_id = pointer.id, origin = pointer.position}
        result.pressed = true
    }
    if !state.active || state.pointer_id != pointer.id {return result}
    delta := layout.Vec2{pointer.position.x - state.origin.x, pointer.position.y - state.origin.y}
    if delta.x * delta.x + delta.y * delta.y >= drag_threshold * drag_threshold {state.dragging = true}
    result.held, result.dragging = pointer.down, state.dragging
    if pointer.released {
        result.released = true
        result.clicked = inside && !state.dragging
        state^ = {}
    }
    return result
}

Scroll :: struct {press: Press, origin_offset: f32}

scroll :: proc(state: ^Scroll, pointer: Pointer, inside: bool, current, maximum, wheel: f32, horizontal: bool = false, drag_threshold: f32 = 8) -> (offset: f32, dragging: bool) {
    // Keep the old origin through release; button clears its capture on release.
    origin := state.press.origin
    event := button(&state.press, pointer, inside, drag_threshold)
    if event.pressed {state.origin_offset = current; origin = pointer.position}
    offset = current
    if inside {offset += wheel}
    if event.dragging {
        delta := pointer.position.x - origin.x if horizontal else pointer.position.y - origin.y
        offset = state.origin_offset - delta
    }
    return clamp(offset, 0, max(0, maximum)), event.dragging
}

focus_next :: proc(current: int, enabled: []int, backwards: bool = false) -> int {
    if len(enabled) == 0 {return -1}
    for id, index in enabled {
        if id == current {return enabled[(index + len(enabled) - 1) % len(enabled)] if backwards else enabled[(index + 1) % len(enabled)]}
    }
    return enabled[len(enabled) - 1] if backwards else enabled[0]
}
