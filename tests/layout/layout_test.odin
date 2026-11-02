package tests

import ui "../../src/layout"
import "core:testing"

Frame :: ui.Frame(int, u32)

@(test)
rounded_hits_preserve_corners_at_extreme_finite_scales :: proc(t: ^testing.T) {
    for extent in ([2]f32{1e20, 1e-25}) {
        frame: Frame
        ui.begin(&frame, extent, extent, {})
        target := ui.leaf(&frame, {width = ui.grow(), height = ui.grow(), radius = extent / 2})
        ui.action(&frame, target, {path = "rounded"})
        testing.expect(t, ui.finish(&frame) == nil)
        testing.expect_value(t, ui.hit(&frame, {0, 0}), {})
        testing.expect_value(t, ui.hit(&frame, {extent / 2, extent / 2}), {path = "rounded"})
        testing.expect_value(t, ui.hit(&frame, {extent / 2, 0}), {path = "rounded"})
    }
}

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

// LayoutDefinition.BalancedAndBoundedInput and LayoutResolution.ResolutionFailure.
@(test)
failed_or_unfinished_frames_never_supply_hits :: proc(t: ^testing.T) {
    frame: Frame
    ui.begin(&frame, 100, 100, {})
    target := ui.leaf(&frame, {width = ui.grow(), height = ui.grow()})
    ui.action(&frame, target, {path = "target"})
    testing.expect_value(t, ui.hit(&frame, {50, 50}), {})
    ui.open(&frame, {})
    failure := ui.finish(&frame)
    testing.expect(t, failure != nil && frame.failure == failure)
    testing.expect(t, ui.finish(&frame) == failure)
    testing.expect(t, !ui.contains(&frame, target, {50, 50}))
    testing.expect_value(t, ui.hit(&frame, {50, 50}), {})
}

// LayoutDefinition.SingleScreenRepresentation: only begin starts another declaration.
@(test)
finalized_frames_are_read_only_until_begin :: proc(t: ^testing.T) {
    for operation in 0 ..< 4 {
        frame: Frame
        ui.begin(&frame, 100, 100, {})
        target := ui.leaf(&frame, {width = ui.grow(), height = ui.grow()})
        ui.action(&frame, target, {path = "target"})
        testing.expect(t, ui.finish(&frame) == nil)
        rect := frame.nodes[target].rect
        testing.expect(t, ui.finish(&frame) == nil)
        testing.expect_value(t, ui.measure_width(&frame, target), frame.nodes[target].measured_width)
        testing.expect_value(t, frame.nodes[target].rect, rect)
        testing.expect_value(t, ui.hit(&frame, {50, 50}), {path = "target"})
        switch operation {
        case 0: ui.leaf(&frame, {})
        case 1: ui.open(&frame, {})
        case 2: ui.close(&frame)
        case 3: ui.action(&frame, target, {path = "changed"})
        }
        testing.expect(t, ui.finish(&frame) != nil && !frame.resolved)
        testing.expect_value(t, ui.hit(&frame, {50, 50}), {})
    }
}

@(test)
caller_storage_is_reused_and_bounds_each_frame :: proc(t: ^testing.T) {
    storage: [3]ui.Node(int, u32)
    frame: Frame
    ui.begin(&frame, 100, 100, {}, storage = storage[:])
    target := ui.leaf(&frame, {width = ui.grow(), height = ui.grow()})
    ui.action(&frame, target, {path = "old"})
    testing.expect(t, ui.finish(&frame) == nil)
    testing.expect(t, raw_data(frame.nodes) == raw_data(storage[:]))
    ui.begin(&frame, 100, 100, {}, storage = storage[:])
    testing.expect(t, ui.finish(&frame) == nil)
    testing.expect_value(t, ui.hit(&frame, {50, 50}), {})
    ui.begin(&frame, 100, 100, {}, storage = storage[:])
    for _ in 0 ..< len(storage) {ui.leaf(&frame, {})}
    _, capacity := ui.finish(&frame).(ui.Node_Capacity_Exceeded)
    testing.expect(t, capacity)
}

@(test)
scroll_measurement_preserves_empty_padding_and_resets_populated_grow :: proc(t: ^testing.T) {
    for horizontal in ([2]bool{false, true}) {
        frame: Frame
        ui.begin(&frame, 100, 100, {alignment = {.start, .start}})
        style := ui.Style(u32){direction = .horizontal if horizontal else .vertical,
            width = ui.grow(), height = ui.grow(), padding = {4, 5, 6, 7}, scroll = true}
        empty := ui.open(&frame, style)
        ui.close(&frame)
        populated := ui.open(&frame, style)
        ui.leaf(&frame, {}, {20, 30})
        ui.close(&frame)
        testing.expect(t, ui.finish(&frame) == nil)
        testing.expect_value(t, frame.nodes[empty].measured_width, f32(10))
        testing.expect_value(t, frame.nodes[empty].measured_height, f32(12))
        testing.expect_value(t, frame.nodes[populated].measured_width, f32(0) if horizontal else f32(30))
        testing.expect_value(t, frame.nodes[populated].measured_height, f32(42) if horizontal else f32(0))
    }
}

@(test)
nested_siblings_keep_order_when_caller_storage_is_reused :: proc(t: ^testing.T) {
    storage: [7]ui.Node(int, u32)
    frame: Frame
    for _ in 0 ..< 2 {
        ui.begin(&frame, 100, 100, {direction = .vertical, alignment = {.start, .start}}, storage = storage[:])
        group := ui.open(&frame, {direction = .horizontal, alignment = {.start, .start}, gap = 3})
        first := ui.leaf(&frame, {}, {10, 20})
        nested := ui.open(&frame, {})
        grandchild := ui.leaf(&frame, {}, {30, 40})
        ui.close(&frame)
        last := ui.leaf(&frame, {}, {5, 10})
        ui.close(&frame)
        footer := ui.leaf(&frame, {}, {50, 10})
        testing.expect_value(t, ui.measure_width(&frame, group), f32(51))
        testing.expect(t, ui.finish(&frame) == nil)
        testing.expect_value(t, frame.nodes[first].rect, {0, 0, 10, 20})
        testing.expect_value(t, frame.nodes[nested].rect, {13, 0, 30, 40})
        testing.expect_value(t, frame.nodes[grandchild].rect, {13, 0, 30, 40})
        testing.expect_value(t, frame.nodes[last].rect, {46, 0, 5, 10})
        testing.expect_value(t, frame.nodes[footer].rect, {0, 40, 50, 10})
    }
}
