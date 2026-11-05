package tests

import input "../../src/input"
import "core:testing"

@(test)
scroll_capture_starts_from_the_current_bounded_offset :: proc(t: ^testing.T) {
    for horizontal in ([2]bool{false, true}) {
        for current in ([2]f32{-200, 200}) {
            state: input.Scroll
            offset, dragging := input.scroll(&state, {id = 1, position = {100, 100}, pressed = true, down = true},
                                             true, current, 100, 0, horizontal)
            start := f32(0) if current < 0 else f32(100)
            testing.expect_value(t, offset, start)
            testing.expect(t, !dragging)
            position := f32(80) if current < 0 else f32(120)
            offset, dragging = input.scroll(&state, {id = 1, position = {position, position}, down = true},
                                             true, offset, 100, 0, horizontal)
            testing.expect_value(t, offset, f32(20) if current < 0 else f32(80))
            testing.expect(t, dragging)
        }
    }
}

@(test)
wheel_scrolling_applies_to_the_current_bounded_offset :: proc(t: ^testing.T) {
    state: input.Scroll
    offset, _ := input.scroll(&state, {}, true, 200, 100, -20)
    testing.expect_value(t, offset, f32(80))
    offset, _ = input.scroll(&state, {}, true, -200, 100, 20)
    testing.expect_value(t, offset, f32(20))
    offset, _ = input.scroll(&state, {}, true, 200, -100, 20)
    testing.expect_value(t, offset, f32(0))
}

@(test)
drag_thresholds_preserve_clicks_at_extreme_finite_scales :: proc(t: ^testing.T) {
    for threshold in ([2]f32{1e20, 1e-25}) {
        capture: input.Press
        pressed := input.button(&capture, {pressed = true, down = true}, true, threshold)
        testing.expect(t, pressed.pressed && !pressed.dragging)
        held := input.button(&capture, {position = {threshold / 2, 0}, down = true}, true, threshold)
        testing.expect(t, held.held && !held.dragging)
        released := input.button(&capture, {position = {threshold / 2, 0}, released = true}, true, threshold)
        testing.expect(t, released.clicked && !released.dragging)
        input.button(&capture, {pressed = true, down = true}, true, threshold)
        testing.expect(t, input.button(&capture, {position = {threshold, 0}, down = true}, true, threshold).dragging)
    }
}

@(test)
capture_drag_and_cancellation :: proc(t: ^testing.T) {
    capture: input.Press
    testing.expect(t, input.button(&capture, {id = 3, position = {20, 20}, pressed = true, down = true}, true).pressed)
    testing.expect(t, !input.button(&capture, {id = 4, released = true}, true).clicked)
    testing.expect(t, capture.active)
    testing.expect(t, input.button(&capture, {id = 3, position = {21, 21}, released = true}, true).clicked)
    testing.expect(t, !capture.active)
    input.button(&capture, {id = 3, pressed = true, down = true}, true)
    testing.expect(t, input.button(&capture, {id = 3, position = {20, 0}, down = true}, false).dragging)
    testing.expect(t, !input.button(&capture, {id = 3, position = {20, 0}, released = true}, true).clicked)
    input.button(&capture, {id = 3, pressed = true, down = true}, true)
    input.button(&capture, {id = 3, cancelled = true}, false)
    testing.expect(t, !capture.active)
}

@(test)
scroll_release_retains_final_drag_position :: proc(t: ^testing.T) {
    scroll: input.Scroll
    input.scroll(&scroll, {id = 1, position = {10, 100}, pressed = true, down = true}, true, 20, 200, 0)
    offset, dragging := input.scroll(&scroll, {id = 1, position = {10, 80}, down = true}, true, 20, 200, 0)
    testing.expect(t, dragging)
    testing.expect_value(t, offset, f32(40))
    offset, dragging = input.scroll(&scroll, {id = 1, position = {10, 70}, released = true}, true, offset, 200, 0)
    testing.expect_value(t, offset, f32(50))
    testing.expect(t, !scroll.press.active)
    offset, _ = input.scroll(&scroll, {}, true, offset, 200, 500)
    testing.expect_value(t, offset, f32(200))
}

@(test)
viewport_and_focus_are_host_independent :: proc(t: ^testing.T) {
    viewport := input.Viewport{width = 800, height = 600, scale = 2, insets = {10, 20, 30, 40}}
    testing.expect_value(t, input.logical_position(viewport, {100, 100}), {50, 50})
    testing.expect_value(t, input.content_bounds(viewport), {10, 20, 760, 540})
    ids := [3]int{10, 20, 30}
    testing.expect_value(t, input.focus_next(30, ids[:]), 10)
    testing.expect_value(t, input.focus_next(10, ids[:], true), 30)
    testing.expect_value(t, input.focus_next(99, nil), -1)
}

@(test)
immediate_scroll_drag_starts_at_current_offset :: proc(t: ^testing.T) {
    for horizontal in ([2]bool{false, true}) {
        scroll: input.Scroll
        offset, dragging := input.scroll(&scroll, {id = 1, position = {100, 100}, pressed = true, down = true},
                                        true, 120, 400, 0, horizontal, 0)
        testing.expect(t, dragging)
        testing.expect_value(t, offset, f32(120))
        offset, _ = input.scroll(&scroll, {id = 1, position = {80, 80}, down = true},
                                  true, offset, 400, 0, horizontal, 0)
        testing.expect_value(t, offset, f32(140))
        offset, _ = input.scroll(&scroll, {id = 1, position = {70, 70}, released = true},
                                  true, offset, 400, 0, horizontal, 0)
        testing.expect_value(t, offset, f32(150))
        testing.expect(t, !scroll.press.active)
    }
}

@(test)
device_snapshots_keep_touch_identity_and_cancel_lost_capture :: proc(t: ^testing.T) {
    touches := [2]input.Touch{{7, {40, 60}}, {3, {10, 20}}}
    selected := input.pointer({}, {}, touches[:], scale = 2)
    testing.expect(t, selected.pressed && selected.down)
    testing.expect_value(t, selected.id, 7)
    testing.expect_value(t, selected.position, {20, 30})
    touches[0], touches[1] = touches[1], touches[0]
    held := input.pointer(selected, {}, touches[:], scale = 2)
    testing.expect(t, held.down && !held.pressed)
    testing.expect_value(t, held.id, 7)
    cancelled := input.pointer(held, {}, touches[:1])
    testing.expect(t, cancelled.cancelled && !cancelled.released)
    testing.expect_value(t, cancelled.id, 7)
    released := input.pointer(held, {})
    testing.expect(t, released.released && !released.down)
    blurred := input.pointer(held, {}, focused = false)
    testing.expect(t, blurred.cancelled && !blurred.down)
    mouse := input.pointer(released, {position = {60, 80}, pressed = true, down = true}, scale = 2)
    testing.expect_value(t, mouse.id, -1)
    testing.expect_value(t, mouse.position, {30, 40})
    testing.expect(t, mouse.pressed && mouse.down)
}

@(test)
touch_selection_preserves_idle_identity_and_delays_replacement_capture :: proc(t: ^testing.T) {
    touches := [2]input.Touch{{7, {40, 60}}, {3, {10, 20}}}
    idle := input.Pointer{id = 3, position = {1, 2}}
    selected := input.pointer(idle, {}, touches[:])
    testing.expect_value(t, selected.id, 3)
    testing.expect_value(t, selected.position, {10, 20})
    testing.expect(t, selected.pressed && selected.down)
    cancelled := input.pointer(selected, {}, touches[:1])
    testing.expect_value(t, cancelled, {id = 3, position = {10, 20}, cancelled = true})
    replacement := input.pointer(cancelled, {}, touches[:1])
    testing.expect_value(t, replacement, {id = 7, position = {40, 60}, pressed = true, down = true})
    mouse := input.Pointer{id = -1, position = {5, 6}, down = true}
    testing.expect_value(t, input.pointer(mouse, {}, touches[:]), {id = -1, position = {5, 6}, cancelled = true})
}
