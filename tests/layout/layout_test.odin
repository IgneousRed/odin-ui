package tests

import ui "../../src/layout"
import "core:testing"

Frame :: ui.Frame(int, u32)

@(test)
layout_is_independent_of_content_and_renderer :: proc(t: ^testing.T) {
    frame: Frame
    ui.begin(&frame, 300, 100, {direction = .horizontal, gap = 10})
    first := ui.leaf(&frame, {width = ui.fixed(80), height = ui.grow()})
    last := ui.leaf(&frame, {width = ui.grow(), height = ui.grow()})
    frame.nodes[first].content = 42
    testing.expect(t, ui.finish(&frame) == nil)
    testing.expect_value(t, frame.nodes[last].rect, {90, 0, 210, 100})
    testing.expect_value(t, frame.nodes[first].content, 42)
}

@(test)
horizontal_scrolling_and_clip_only_containers :: proc(t: ^testing.T) {
    frame: Frame
    ui.begin(&frame, 100, 40, {})
    parent := ui.open(&frame, {direction = .horizontal, width = ui.grow(), height = ui.grow(), scroll = true, scroll_offset = 200})
    first := ui.leaf(&frame, {width = ui.fixed(80), height = ui.grow()})
    second := ui.leaf(&frame, {width = ui.fixed(80), height = ui.grow()})
    ui.close(&frame)
    testing.expect(t, ui.finish(&frame) == nil)
    testing.expect_value(t, frame.nodes[parent].max_scroll, f32(60))
    testing.expect_value(t, frame.nodes[first].rect.x, f32(-60))
    testing.expect(t, ui.contains(&frame, second, {50, 20}))
    testing.expect(t, !ui.contains(&frame, first, {-10, 20}))
    ui.begin(&frame, 100, 40, {})
    ui.open(&frame, {width = ui.fixed(20), height = ui.fixed(20), clip_content = true})
    item := ui.leaf(&frame, {width = ui.fixed(80), height = ui.fixed(80)})
    ui.close(&frame)
    testing.expect(t, ui.finish(&frame) == nil)
    testing.expect(t, !ui.contains(&frame, item, {0, 0}))
}

@(test)
invalid_numbers_and_capacity_fail_explicitly :: proc(t: ^testing.T) {
    frame: Frame
    ui.begin(&frame, transmute(f32)u32(0x7fc00000), 100, {})
    testing.expect(t, ui.finish(&frame) != nil)
    ui.begin(&frame, 100, 100, {})
    for _ in 0 ..< ui.DEPTH_CAPACITY {ui.open(&frame, {})}
    testing.expect(t, ui.finish(&frame) != nil)
}

@(test)
fractional_dpi_clips_round_both_edges :: proc(t: ^testing.T) {
    testing.expect_value(t, ui.pixel_bounds({0.9, 0.9, 0.2, 0.2}), {0, 0, 2, 2})
    testing.expect_value(t, ui.pixel_bounds({1.25, 2.25, 3.5, 4.5}, 2), {2, 4, 8, 10})
    testing.expect_value(t, ui.pixel_bounds({0, 0, 0, 10}), {})
    testing.expect_value(t, ui.pixel_bounds({0, 0, 2, 2}, 2e38), {})
    testing.expect_value(t, ui.pixel_bounds({2e38, 0, 2e38, 1}), {})
    testing.expect_value(t, ui.pixel_bounds({0, 2e38, 1, 2e38}), {})
}

@(test)
empty_content_keeps_its_padding :: proc(t: ^testing.T) {
    frame: Frame
    ui.begin(&frame, 100, 100, {})
    empty := ui.open(&frame, {padding = {4, 5, 6, 7}})
    ui.close(&frame)
    populated := ui.open(&frame, {padding = {4, 5, 6, 7}})
    ui.leaf(&frame, {})
    ui.close(&frame)
    testing.expect(t, ui.finish(&frame) == nil)
    for index in ([2]int{empty, populated}) {
        testing.expect_value(t, frame.nodes[index].rect.width, f32(10))
        testing.expect_value(t, frame.nodes[index].rect.height, f32(12))
    }
}

@(test)
finite_input_overflow_fails_resolution :: proc(t: ^testing.T) {
    for fixed in ([2]bool{false, true}) {
        frame: Frame
        ui.begin(&frame, 100, 100, {width = ui.fixed(100) if fixed else nil})
        ui.leaf(&frame, {}, {3e38, 10})
        ui.leaf(&frame, {}, {3e38, 10})
        _, invalid := ui.finish(&frame).(ui.Invalid_Dimensions)
        testing.expect(t, invalid, "Finite inputs must not resolve successfully to infinite or NaN geometry")
    }
}

@(test)
resolved_edges_remain_finite :: proc(t: ^testing.T) {
    for horizontal in ([2]bool{false, true}) {
        frame: Frame
        ui.begin(&frame, 3e38, 3e38, {
            width = ui.fixed(3e38), height = ui.fixed(3e38),
            padding = {left = 3e38} if horizontal else {top = 3e38},
            alignment = {.start, .start},
        })
        ui.leaf(&frame, {width = ui.fixed(3e38), height = ui.fixed(3e38)})
        _, invalid := ui.finish(&frame).(ui.Invalid_Dimensions)
        testing.expect(t, invalid, "Finite rectangle components must not hide an infinite right or bottom edge")
    }
}
