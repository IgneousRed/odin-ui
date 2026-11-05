package tests

import imui "../../src/raylib"
import text "../../src/text"
import "core:testing"
import rl "vendor:raylib"

@(test)
growing_labels_and_controls_start_at_their_measured_content_size :: proc(t: ^testing.T) {
    font := monospace_font()
    for control in 0 ..< 3 {
        frame: imui.UI
        imui.begin(&frame, 100, 40, {alignment = {.start, .start}})
        nodes: [2]int
        for value, index in ([2]string{"A", "Widest"}) {
            switch control {
            case 0: nodes[index] = imui.text(&frame, font, value, 10, rl.WHITE, {width = imui.grow()})
            case 1: nodes[index] = imui.button(&frame, font, value, 10, rl.BLUE, rl.DARKBLUE, {}, {width = imui.grow()})
            case 2: nodes[index] = imui.field(&frame, font, value, 10, rl.BLUE, rl.DARKBLUE, {}, {width = imui.grow()})
            }
        }
        testing.expect(t, imui.finish(&frame) == nil)
        testing.expect_value(t, frame.nodes[nodes[0]].rect.width, f32(25))
        testing.expect_value(t, frame.nodes[nodes[1]].rect.width, f32(75))
    }
}

@(test)
explicit_control_dimensions_do_not_hide_invalid_text_measurements :: proc(t: ^testing.T) {
    font := monospace_font()
    for control in 0 ..< 3 {
        for size in ([4]f32{-1, transmute(f32)u32(0x7fc00000), transmute(f32)u32(0x7f800000), 1e38}) {
            frame: imui.UI
            imui.begin(&frame, 100, 40)
            switch control {
            case 0: imui.text(&frame, font, "Widest", size, rl.WHITE, {width = imui.fixed(20), height = imui.fixed(20)})
            case 1: imui.button(&frame, font, "Widest", size, rl.BLUE, rl.DARKBLUE, {}, {width = imui.fixed(20), height = imui.fixed(20)})
            case 2: imui.field(&frame, font, "Widest", size, rl.BLUE, rl.DARKBLUE, {}, {width = imui.fixed(20), height = imui.fixed(20)})
            }
            testing.expect(t, imui.finish(&frame) != nil)
        }
    }
}

// -------------------------------- Public --------------------------------

// ---------------- Procedures ----------------

@(test)
empty_optional_surface_needs_no_window :: proc(t: ^testing.T) {
	frame: imui.UI
	imui.draw(&frame)
	testing.expect_value(t, frame.count, 0)
}

@(test)
unrepresentable_clips_are_rejected_without_rendering :: proc(t: ^testing.T) {
    for extent in ([3]f32{2, f32(1 << 31), 2e38}) {
        frame: imui.UI
        imui.begin(&frame, extent, extent)
        testing.expect(t, imui.finish(&frame) == nil)
        scale := f32(2e38) if extent == 2 else 1
        testing.expect(t, !imui.begin_clip(&frame, 0, scale), "Reject overflow before converting scissor coordinates or calling raylib")
    }
}

@(test)
text_point_and_rounded_hit_rules :: proc(t: ^testing.T) {
	testing.expect_value(t, imui.text_pixels(10), 32)
	testing.expect_value(t, imui.text_pixels(12), 64)
	testing.expect_value(t, imui.text_pixels(14), 128)
	testing.expect_value(t, imui.text_pixels(8), 16)
	testing.expect_value(t, imui.button_radius(64), 16)
	testing.expect_value(t, imui.control_width(100, 32), f32(108))
	testing.expect_value(t, imui.control_height(32), f32(40))
	rect := imui.Layout_Rect {
		width  = 100,
		height = 48,
	}
	testing.expect(t, !imui.rounded_rect_contains({0, 0}, rect, 8))
	testing.expect(t, imui.rounded_rect_contains({0, 8}, rect, 8))
	testing.expect(t, imui.rounded_rect_contains({50, 24}, rect, 8))
	testing.expect(t, imui.rounded_rect_contains({5, 0}, {width = 10, height = 40}, 16))
	testing.expect(t, !imui.rounded_rect_contains({0, 0}, {width = 10, height = 40}, 16))
	testing.expect(t, !imui.rounded_rect_contains({0, 0}, {}, 16))
}

@(test)
layout_balances_only_explicitly_opened_containers :: proc(t: ^testing.T) {
	frame: imui.UI
	imui.begin(&frame, 100, 100)
	imui.layout_open(&frame, {})
	imui.close(&frame)
	testing.expect(t, imui.finish(&frame) == nil)

	imui.begin(&frame, 100, 100)
	imui.close(&frame)
	_, unbalanced := frame.failure.(imui.Layout_Unbalanced)
	testing.expect(t, unbalanced)
}

@(test)
fit_compresses_on_the_cross_axis :: proc(t: ^testing.T) {
	frame: imui.UI
	imui.begin(&frame, 40, 20)
	container := imui.layout_open(&frame, {width = nil, height = imui.fixed(10)})
	imui.layout_leaf(&frame, {width = imui.fixed(100), height = imui.fixed(10)})
	imui.close(&frame)
	testing.expect(t, imui.finish(&frame) == nil)
	testing.expect_value(t, frame.nodes[container].rect.width, f32(40))
}

@(test)
controls_hit_only_their_visible_rounded_geometry :: proc(t: ^testing.T) {
    font := monospace_font()
    for size in ([4]rl.Vector2{{100, 40}, {4, 40}, {100, 4}, {0, 40}}) {
        frame: imui.UI
        imui.begin(&frame, 200, 100, {direction = .horizontal, gap = 10, alignment = {.start, .start}})
        button := imui.button(&frame, font, "Button", 32, rl.BLUE, rl.DARKBLUE, {path = "button"},
                              {width = imui.fixed(size.x), height = imui.fixed(size.y)})
        field := imui.field(&frame, font, "Field", 32, rl.BLUE, rl.DARKBLUE, {path = "field"},
                            {width = imui.fixed(size.x), height = imui.fixed(size.y)})
        testing.expect(t, imui.finish(&frame) == nil)
        for index in ([2]int{button, field}) {
            bounds := frame.nodes[index].rect
            testing.expect_value(t, imui.hit(&frame, {bounds.x, bounds.y}), {})
            centre := rl.Vector2{bounds.x + bounds.width / 2, bounds.y + bounds.height / 2}
            expected := frame.nodes[index].trigger if bounds.width > 0 else imui.Trigger{}
            testing.expect_value(t, imui.hit(&frame, centre), expected)
            if bounds.width > 0 {
                radius := min(f32(8), min(bounds.width, bounds.height) / 2)
                testing.expect_value(t, imui.hit(&frame, {bounds.x + radius, bounds.y}), expected)
            }
        }
    }
}

@(test)
actions_use_the_same_trigger_for_controls_and_containers :: proc(t: ^testing.T) {
    font := monospace_font()
    payload := 42
    paths := [5]string{"button", "field", "container", "scroll column", "scroll row"}
    for replace in ([2]bool{false, true}) {
        frame: imui.UI
        imui.begin(&frame, 300, 50, {direction = .horizontal, alignment = {.start, .start}})
        button := imui.button(&frame, font, "Button", 10, rl.BLUE, rl.DARKBLUE, {path = "button"})
        field := imui.field(&frame, font, "Field", 10, rl.BLUE, rl.DARKBLUE, {path = "field"})
        container := imui.column(&frame, {width = imui.fixed(50), height = imui.fixed(20)})
        imui.close(&frame)
        imui.action(&frame, container, {path = "container"})
        scroll_column := imui.scroll_column(&frame, 0, {width = imui.fixed(50), height = imui.fixed(20)})
        imui.close(&frame)
        imui.action(&frame, scroll_column, {path = "scroll column"})
        scroll_row := imui.scroll_row(&frame, 0, {width = imui.fixed(50), height = imui.fixed(20)})
        imui.close(&frame)
        imui.action(&frame, scroll_row, {path = "scroll row"})
        indexes := [5]int{button, field, container, scroll_column, scroll_row}
        for index in indexes {
            if replace {imui.action(&frame, index, {path = "replacement", data = &payload})}
        }
        testing.expect(t, imui.finish(&frame) == nil)
        for index, ordinal in indexes {
            bounds := frame.nodes[index].rect
            expected := imui.Trigger{path = paths[ordinal]}
            if replace {expected = {path = "replacement", data = &payload}}
            testing.expect_value(t, imui.node_trigger(&frame.nodes[index]), expected)
            testing.expect_value(t, imui.hit(&frame, {bounds.x + bounds.width / 2, bounds.y + bounds.height / 2}), expected)
        }
    }
}

@(test)
controls_keep_the_text_that_was_measured :: proc(t: ^testing.T) {
    frame: imui.UI
    source: [8]u8
    copy(source[:], "A notice")
    font := monospace_font()
    imui.begin(&frame, 200, 100, {direction = .vertical})
    button := imui.button(&frame, font, string(source[:]), 10, rl.BLUE, rl.DARKBLUE, {})
    value, selection := text.edit(string(source[:]), {}, .select_all)
    field := imui.field(&frame, font, value, 10, rl.BLUE, rl.DARKBLUE, {}, {selection = selection, cursor = true})
    value, selection = text.edit(value, selection, .insert, "New")
    testing.expect_value(t, value, "New")
    testing.expect_value(t, selection, {3, 3})
    source[0] = 'X'
    testing.expect(t, imui.finish(&frame) == nil)
    for index in ([2]int{button, field}) {
        content := frame.nodes[index].content.(imui.Layout_Button)
        testing.expect_value(t, content.value, "A notice")
        testing.expect_value(t, frame.nodes[index].rect.width, f32(82.5))
    }
    content := frame.nodes[field].content.(imui.Layout_Button)
    testing.expect_value(t, content.selection, {0, 8})
}

@(test)
actions_ignore_indexes_outside_the_active_frame :: proc(t: ^testing.T) {
    frame: imui.UI
    imui.action(&frame, 0, {path = "uninitialized"})
    imui.begin(&frame, 100, 100)
    imui.action(&frame, -1, {path = "negative"})
    imui.action(&frame, frame.count, {path = "inactive"})
    imui.action(&frame, len(frame.nodes), {path = "out of bounds"})
    testing.expect_value(t, frame.nodes[frame.count].trigger, {})
    imui.action(&frame, 0, {path = "root"})
    testing.expect(t, imui.finish(&frame) == nil)
    testing.expect_value(t, imui.hit(&frame, {50, 50}), {path = "root"})
}
