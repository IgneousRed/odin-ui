package tests

import input "../../src/input"
import "core:testing"

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
