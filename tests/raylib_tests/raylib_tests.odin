package raylib_tests

// -------------------------------- Imports --------------------------------

// ---------------- Vendor ----------------

import rl "vendor:raylib"

// ---------------- Odin ----------------

import "core:mem"
import "core:testing"

// ---------------- Project ----------------

import imui "../../src/raylib"
import text "../../src/text"

// -------------------------------- Procedures --------------------------------

// ---------------- Public ----------------

@(test)
hsl_round_trips_preserve_byte_colors :: proc(t: ^testing.T) {
	channels := [9]u8{0, 1, 31, 63, 127, 128, 191, 254, 255}
	for red in channels {
		for green in channels {
			for blue in channels {
				color := rl.Color{red, green, blue, 255}
				if !testing.expect_value(t, imui.hsl_color(imui.color_hsl(color)), color) {return}
				if !testing.expect_value(t, imui.hsl_blend(color, color, 0.5), color) {return}
			}
		}
	}
}

@(test)
hsl_hues_wrap_in_both_directions :: proc(t: ^testing.T) {
	primaries := [6]rl.Color{{255, 0, 0, 255}, {255, 255, 0, 255}, {0, 255, 0, 255},
							{0, 255, 255, 255}, {0, 0, 255, 255}, {255, 0, 255, 255}}
	for expected, sector in primaries {
		for turns in -2 ..= 2 {
			hue := f32(sector * 60 + turns * 360)
			testing.expect_value(t, imui.hsl(hue, 1, 0.5), expected)
			testing.expect_value(t, imui.hsl_color({hue, 1, 0.5}), expected)
		}
	}
}

@(test)
hsl_blends_preserve_and_interpolate_opacity :: proc(t: ^testing.T) {
	start := rl.Color{255, 0, 0, 32}
	end := rl.Color{0, 0, 255, 224}
	testing.expect_value(t, imui.hsl_blend(start, end, 0), start)
	testing.expect_value(t, imui.hsl_blend(start, end, 1), end)
	testing.expect_value(t, imui.hsl_blend(start, end, 0.5), {255, 0, 255, 128})
	testing.expect_value(t, imui.hsl_blend({0, 0, 0, 0}, {0, 0, 0, 0}, 0.5), {})
	testing.expect_value(t, imui.hsl_blend({255, 0, 0, 0}, {255, 0, 0, 255}, 0.5), {255, 0, 0, 128})
}

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

@(test)
layout_widths_follow_the_viewport :: proc(t: ^testing.T) {
	frame: imui.UI
	for width in ([3]f32{960,1280,1920}) {
		imui.begin(&frame,width,675,{direction=.horizontal,alignment={.start,.start},gap=12})
		navigation:=imui.layout_leaf(&frame,{width=imui.fixed(213),height=imui.grow()})
		content:=imui.layout_leaf(&frame,{width=imui.grow(),height=imui.grow()})
		testing.expect(t,imui.finish(&frame)==nil)
		testing.expect_value(t,frame.nodes[navigation].rect.width,f32(213))
		testing.expect_value(t,frame.nodes[content].rect.width,width-225)
		testing.expect_value(t,frame.nodes[content].rect.x,f32(225))
	}
}

@(test)
scrolling_preserves_content_and_clips_hits :: proc(t: ^testing.T) {
	frame: imui.UI
	imui.begin(&frame,200,100,{direction=.vertical,alignment={.start,.start}})
	scroll:=imui.column(&frame,{width=imui.grow(),height=imui.grow(),scroll=true,scroll_offset=100,alignment={.start,.start}})
	first:=imui.layout_leaf(&frame,{width=imui.grow(),height=imui.fixed(80)})
	last:=imui.layout_leaf(&frame,{width=imui.grow(),height=imui.fixed(80)})
	imui.close(&frame)
	footer:=imui.layout_leaf(&frame,{width=imui.grow(),height=imui.fixed(20)})
	testing.expect(t,imui.finish(&frame)==nil)
	testing.expect_value(t,frame.nodes[scroll].rect.height,f32(80))
	testing.expect_value(t,frame.nodes[scroll].max_scroll,f32(80))
	testing.expect_value(t,frame.nodes[first].rect.y,f32(-80))
	testing.expect(t,!imui.contains(&frame,first,{10,10}),"Scrolled-away controls cannot receive hits")
	testing.expect(t,imui.contains(&frame,last,{10,50}))
	testing.expect(t,!imui.contains(&frame,last,{10,90}),"The footer clips page controls")
	testing.expect_value(t,frame.nodes[footer].rect.y,f32(80))
}

@(test)
layout_rejects_invalid_or_unbalanced_trees :: proc(t: ^testing.T) {
	frame: imui.UI
	testing.expect_value(t,imui.separator(&frame,rl.WHITE),imui.INVALID_LAYOUT_INDEX)
	testing.expect(t,imui.finish(&frame)!=nil,"A separator needs an open parent")
	imui.begin(&frame,-1,100)
	testing.expect_value(t,imui.separator(&frame,rl.WHITE),imui.INVALID_LAYOUT_INDEX)
	testing.expect(t,imui.finish(&frame)!=nil)
	imui.begin(&frame,100,100)
	imui.column(&frame)
	testing.expect(t,imui.finish(&frame)!=nil)
	imui.begin(&frame,100,100)
	imui.close(&frame)
	testing.expect(t,imui.finish(&frame)!=nil)
	imui.begin(&frame,100,100)
	for _ in 0..<imui.NODE_CAPACITY {imui.layout_leaf(&frame,{})}
	testing.expect(t,imui.finish(&frame)!=nil,"Capacity exhaustion is explicit")
}

@(test)
rounded_hits_match_visible_corners :: proc(t: ^testing.T) {
	bounds:=imui.Layout_Rect{width=100,height=40}
	testing.expect(t,!imui.rounded_rect_contains({0,0},bounds,8))
	testing.expect(t,imui.rounded_rect_contains({50,20},bounds,8))
	testing.expect(t,!imui.rounded_rect_contains({1,1},{},8))
}

@(test)
wrapped_text_uses_resolved_width_and_rune_boundaries :: proc(t: ^testing.T) {
	frame: imui.UI
	font:=monospace_font()
	imui.begin(&frame,60,200,{direction=.vertical,alignment={.start,.start}})
	node:=imui.paragraph(&frame,font,"one two three",10,rl.WHITE)
	testing.expect(t,imui.finish(&frame)==nil)
	testing.expect_value(t,frame.nodes[node].rect.height,f32(42))
	lines:=imui.text_lines({font=font,value="ééééé",pixel_size=10},20)
	testing.expect_value(t,len(lines),3)
	testing.expect_value(t,lines[0],"éé")
	testing.expect_value(t,lines[1],"éé")
	testing.expect_value(t,lines[2],"é")
	lines=imui.text_lines({font=font,value="one\n\ntwo",pixel_size=10},100)
	testing.expect_value(t,len(lines),3)
	testing.expect_value(t,lines[1],"")
}

@(test)
single_line_paragraphs_preserve_small_positive_heights :: proc(t: ^testing.T) {
	font := monospace_font()
	for size in ([3]f32{1e-7, 1e-10, 1e-25}) {
		frame: imui.UI
		imui.begin(&frame, 100, 100, {direction = .vertical, alignment = {.start, .start}})
		node := imui.paragraph(&frame, font, "a", size, rl.WHITE)
		testing.expect(t, imui.finish(&frame) == nil)
		testing.expect_value(t, frame.nodes[node].rect.height, size)
	}
}

@(test)
presented_text_owns_a_copy_of_transaction_rows :: proc(t: ^testing.T) {
	frame: imui.UI
	source: [8]u8
	copy(source[:],"A notice")
	imui.begin(&frame,200,100)
	node:=imui.paragraph(&frame,{},string(source[:]),18,rl.WHITE)
	source[0]='X'
	content:=frame.nodes[node].content.(imui.Layout_Text)
	testing.expect(t,content.value=="A notice","The next input and layout inspection must not retain stack-backed report text")
}

@(test)
fit_labels_leave_remaining_width_for_content :: proc(t: ^testing.T) {
	frame: imui.UI
	font:=monospace_font()
	imui.begin(&frame,400,100,{direction=.horizontal,alignment={.start,.start},gap=12})
	sidebar:=imui.column(&frame,{padding={8,0,8,0},alignment={.start,.start}})
	imui.paragraph(&frame,font,"Navigation",10,rl.WHITE,width=nil)
	imui.close(&frame)
	testing.expect_value(t,imui.measure_width(&frame,sidebar),f32(116))
	content:=imui.column(&frame,{width=imui.grow(),alignment={.start,.start}})
	imui.paragraph(&frame,font,"A paragraph wraps to the remaining space",10,rl.WHITE)
	imui.close(&frame)
	testing.expect(t,imui.finish(&frame)==nil)
	testing.expect_value(t,frame.nodes[sidebar].rect.width,f32(116))
	testing.expect_value(t,frame.nodes[content].rect.x,f32(128))
	testing.expect_value(t,frame.nodes[content].rect.width,f32(272))
}

@(test)
compact_groups_share_the_widest_control_and_center_labels :: proc(t: ^testing.T) {
	frame: imui.UI
	font:=monospace_font()
	imui.begin(&frame,200,100)
	group:=imui.column(&frame,{padding={8,0,8,0},gap=4,alignment={.stretch,.start}})
	controls,labels: [2]int
	for label,index in ([2]string{"A","Widest"}) {
		controls[index]=imui.column(&frame,{padding={12,4,12,4}})
		labels[index]=imui.paragraph(&frame,font,label,10,rl.WHITE,width=nil)
		imui.close(&frame)
	}
	imui.close(&frame)
	testing.expect(t,imui.finish(&frame)==nil)
	testing.expect_value(t,frame.nodes[group].rect.width,f32(100))
	testing.expect_value(t,frame.nodes[group].rect.x,f32(50))
	for control,index in controls {
		bounds:=frame.nodes[control].rect
		label:=frame.nodes[labels[index]].rect
		testing.expect_value(t,bounds.width,f32(84))
		testing.expect_value(t,label.x+label.width/2,bounds.x+bounds.width/2)
	}
}

@(test)
paragraphs_reject_invalid_sizes_and_wrap_at_fractional_width :: proc(t: ^testing.T) {
	font := monospace_font()
	for size in ([3]f32{-1, transmute(f32)u32(0x7fc00000), transmute(f32)u32(0x7f800000)}) {
		frame: imui.UI
		imui.begin(&frame, 100, 100)
		imui.paragraph(&frame, font, "text", size, rl.WHITE)
		testing.expect(t, imui.finish(&frame) != nil)
	}
	frame: imui.UI
	imui.begin(&frame, 100, 100, {direction = .vertical, alignment = {.start, .start}})
	paragraph := imui.paragraph(&frame, font, "aaaa", 0.4, rl.WHITE, width = imui.fixed(0.5))
	testing.expect(t, imui.finish(&frame) == nil)
	testing.expect_value(t, len(imui.text_lines(frame.nodes[paragraph].content.(imui.Layout_Text), 0.5)), 4)
	testing.expect_value(t, frame.nodes[paragraph].rect.height, f32(19.6))
}

// LayoutResolution.BuilderOwnsMeasurement: wrapping is derived, styles remain declarations.
@(test)
wrapping_preserves_declared_sizing_and_prepares_lines_once :: proc(t: ^testing.T) {
	frame: imui.UI
	font := monospace_font()
	imui.begin(&frame, 60, 200, {direction = .vertical, alignment = {.start, .start}})
	paragraph := imui.paragraph(&frame, font, "one two three", 10, rl.WHITE)
	style := frame.nodes[paragraph].style
	testing.expect(t, imui.finish(&frame) == nil)
	testing.expect_value(t, frame.nodes[paragraph].style, style)
	content := frame.nodes[paragraph].content.(imui.Layout_Text)
	testing.expect_value(t, len(content.wrapped_lines), 3)
	lines := raw_data(content.wrapped_lines)
	rect := frame.nodes[paragraph].rect
	testing.expect(t, imui.finish(&frame) == nil)
	testing.expect(t, raw_data(frame.nodes[paragraph].content.(imui.Layout_Text).wrapped_lines) == lines)
	testing.expect_value(t, frame.nodes[paragraph].rect, rect)
}

@(test)
presentation_text_survives_a_scratch_reset :: proc(t: ^testing.T) {
	font := monospace_font()
	presentation_buffer, scratch_buffer: [16384]u8
	presentation, scratch: mem.Arena
	mem.arena_init(&presentation, presentation_buffer[:])
	mem.arena_init(&scratch, scratch_buffer[:])
	context.temp_allocator = mem.arena_allocator(&scratch)
	storage: [3]imui.Node
	frame: imui.UI
	source := [7]u8{'o', 'n', 'e', ' ', 't', 'w', 'o'}
	imui.begin(&frame, 60, 100, {}, allocator = mem.arena_allocator(&presentation), storage = storage[:])
	paragraph := imui.paragraph(&frame, font, string(source[:]), 10, rl.WHITE)
	testing.expect(t, imui.finish(&frame) == nil)
	free_all(context.temp_allocator)
	source[0] = 'X'
	content := frame.nodes[paragraph].content.(imui.Layout_Text)
	testing.expect_value(t, content.value, "one two")
	testing.expect_value(t, content.wrapped_lines[0], "one")
	testing.expect_value(t, content.wrapped_lines[1], "two")
}

@(test)
wrapped_content_obeys_fixed_sizing_and_remains_scrollable :: proc(t: ^testing.T) {
	font := monospace_font()
	frame: imui.UI
	imui.begin(&frame, 60, 20, {direction = .vertical})
	paragraph := imui.paragraph(&frame, font, "one two three", 10, rl.WHITE)
	frame.nodes[paragraph].style.height = imui.fixed(12)
	testing.expect(t, imui.finish(&frame) == nil)
	testing.expect_value(t, frame.nodes[paragraph].rect.height, f32(12))
	imui.begin(&frame, 60, 20, {direction = .vertical})
	scroll := imui.scroll_column(&frame, 0, {width = imui.grow(), height = imui.grow()})
	paragraph = imui.paragraph(&frame, font, "one two three", 10, rl.WHITE)
	imui.close(&frame)
	testing.expect(t, imui.finish(&frame) == nil)
	testing.expect_value(t, frame.nodes[paragraph].rect.height, f32(42))
	testing.expect_value(t, frame.nodes[scroll].max_scroll, f32(22))
}

@(test)
prepared_field_positions_match_raylib_advances :: proc(t: ^testing.T) {
	font := monospace_font()
	font.glyphs['a'].advanceX = 7
	font.glyphs['b'].advanceX = 0
	font.glyphs['b'].offsetX = 2
	font.recs['b'].width = 9
	value := "abé🙂\naab"
	builder: imui.Layout_Builder
	storage: [2]imui.Layout_Node
	imui.begin_layout(&builder, 200, 100, storage = storage[:])
	handle := imui.field_layout(&builder, font, value, 13)
	_, failure := imui.finish_layout(&builder)
	testing.expect(t, failure == nil)
	content := storage[handle.index].content
	start := 0
	for codepoint, offset in value {
		expected := imui.measure_text(font, value[start:offset], 13).x
		testing.expect_value(t, content.positions[offset].x, expected)
		if codepoint == '\n' {start = offset + 1}
	}
	testing.expect_value(t, content.positions[len(value)].x, imui.measure_text(font, value[start:], 13).x)
}

// No window or GPU is needed to measure this monospace font.
monospace_font :: proc() -> rl.Font {
	glyphs:=make([]rl.GlyphInfo,256,context.temp_allocator)
	rectangles:=make([]rl.Rectangle,256,context.temp_allocator)
	for &glyph,index in glyphs {glyph.value=rune(index);glyph.advanceX=10;rectangles[index].width=10}
	return {texture={id=1},baseSize=10,glyphCount=256,glyphs=raw_data(glyphs),recs=raw_data(rectangles)}
}
