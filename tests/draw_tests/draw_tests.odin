package draw_tests

// -------------------------------- Imports --------------------------------

// ---------------- Vendor ----------------

import rl "vendor:raylib"

// ---------------- Odin ----------------

import "base:runtime"
import "core:testing"
import "core:mem"
import "core:fmt"

// ---------------- Project ----------------

import ui "../../src/raylib"
import text "../../src/text"

// -------------------------------- Constants --------------------------------

// ---------------- Public ----------------

CAPTURE_CAPACITY :: 16

// -------------------------------- Globals --------------------------------

// ---------------- Public ----------------

rectangles: [CAPTURE_CAPACITY]rl.Rectangle
rectangle_count: int
text_origin: rl.Vector2
text_count: int
rounded_count: int
paint_colors: [CAPTURE_CAPACITY]rl.Color
clip_bounds: rl.Rectangle

// -------------------------------- Procedures --------------------------------

// ---------------- Public ----------------

// Interpose drawing only; measurement still uses the real raylib implementation.
// ELF uses --wrap with the bundled static archive; macOS interposes its dylib.
@(export, link_name = "__wrap_BeginScissorMode" when ODIN_OS == .Linux else "BeginScissorMode")
capture_begin_clip :: proc "c" (x, y, width, height: i32) {clip_bounds = {f32(x), f32(y), f32(width), f32(height)}}

@(export, link_name = "__wrap_EndScissorMode" when ODIN_OS == .Linux else "EndScissorMode")
capture_end_clip :: proc "c" () {}

@(export, link_name = "__wrap_DrawRectangleRec" when ODIN_OS == .Linux else "DrawRectangleRec")
capture_rectangle :: proc "c" (rect: rl.Rectangle, color: rl.Color) {
	context = runtime.default_context()
	assert(rectangle_count < len(rectangles))
	rectangles[rectangle_count] = rect
	paint_colors[rectangle_count] = color
	rectangle_count += 1
}

@(export, link_name = "__wrap_DrawRectangleRounded" when ODIN_OS == .Linux else "DrawRectangleRounded")
capture_rounded :: proc "c" (rect: rl.Rectangle, roundness: f32, segments: i32, color: rl.Color) {rounded_count += 1}

@(export, link_name = "__wrap_DrawRectangleRoundedLinesEx" when ODIN_OS == .Linux else "DrawRectangleRoundedLinesEx")
capture_border :: proc "c" (rect: rl.Rectangle, roundness: f32, segments: i32, width: f32, color: rl.Color) {}

@(export, link_name = "__wrap_DrawTextCodepoints" when ODIN_OS == .Linux else "DrawTextCodepoints")
capture_text :: proc "c" (font: rl.Font, points: ^rune, count: i32, origin: rl.Vector2, size, spacing: f32, color: rl.Color) {
	if text_count == 0 {text_origin = origin}
	text_count += 1
}

@(test)
field_cursor_and_overlays_remain_stable_while_blinking :: proc(t: ^testing.T) {
	font := monospace_font()
	cases := []struct {value: string, selection: text.Selection, width: f32}{
		{"abcdefghijklmnopqrst", {20, 20}, 100},
		{"abcdefghijklmnopqrst", {0, 0}, 100},
		{"abcdefghijklmnopqrst", {0, 20}, 100},
		{"abcdefghijklmnopqrst", {20, 0}, 100},
		{"abcdefghijklmnopqrst", {10, 10}, 100},
		{"ab\nabcdefghijklmnopqrst", {23, 23}, 100},
		{"abcdefghijklmnopqrst\nab", {23, 23}, 100},
		{"éééééééééééééééééééé", {40, 40}, 100},
		{"abcdefghijklmnopqrst", {20, 20}, 2},
		{"abcdefghijklmnopqrst", {20, 20}, 1},
		{"", {0, 0}, 100},
	}
	for test in cases {
		saved_origin: rl.Vector2
		saved_rectangles: [CAPTURE_CAPACITY]rl.Rectangle
		saved_count: int
		for visible in ([]bool{true, false}) {
			rectangle_count = 0
			text_count = 0
			frame: ui.Layout_Builder
			ui.begin_layout(&frame, test.width, 100, {direction = .vertical, alignment = {.start, .start}})
			handle := ui.field_layout(&frame, font, test.value, 10, {}, {width = ui.fixed(test.width)})
			resolved, failure := ui.finish_layout(&frame)
			testing.expect(t, failure == nil)
			paint: ui.Paint
			ui.begin_paint(&paint, resolved)
			testing.expect(t, ui.paint_field(&paint, handle, {background = rl.WHITE, foreground = rl.BLACK, cursor = visible, selection = test.selection, selection_background = rl.BLUE}))
			ui.end_paint(&paint)
			if visible {
				caret := rectangles[rectangle_count - 1]
				testing.expect(t, caret.x >= 0 && caret.x + caret.width <= test.width, "Caret must remain inside the field")
				saved_origin = text_origin
				saved_count = rectangle_count - 1
				for rectangle in 0 ..< saved_count {saved_rectangles[rectangle] = rectangles[rectangle]}
			} else {
				testing.expect(t, text_origin == saved_origin, "Text must remain stable while the caret blinks")
				testing.expect(t, rectangle_count == saved_count)
				for rectangle in 0 ..< saved_count {testing.expect(t, rectangles[rectangle] == saved_rectangles[rectangle], "overlay moved while caret hidden")}
			}
		}
	}
	rectangle_count = 0
	text_count = 0
	frame: ui.Layout_Builder
	ui.begin_layout(&frame, 100, 100, {direction = .vertical, alignment = {.start, .start}})
	handle := ui.button_layout(&frame, font, "abcdefghijklmnopqrst", 10, {}, {width = ui.fixed(100)})
	resolved, failure := ui.finish_layout(&frame)
	testing.expect(t, failure == nil)
	paint: ui.Paint
	ui.begin_paint(&paint, resolved)
	testing.expect(t, ui.paint_button(&paint, handle, {background = rl.WHITE, foreground = rl.BLACK}))
	ui.end_paint(&paint)
	testing.expect(t, text_origin.x == -50, "ordinary button centering changed")
}

@(test)
multiline_overlays_follow_their_measured_lines :: proc(t: ^testing.T) {
	font := monospace_font()
	defer rl.SetTextLineSpacing(0)
	cases := []struct {value: string, selection: text.Selection, spacing: i32, highlights: []rl.Rectangle, caret: rl.Vector2}{
		{"ab\nc", {3, 4}, 2, {{0, 12, 10, 10}}, {10, 12}},
		{"ab\nc", {4, 3}, 2, {{0, 12, 10, 10}}, {0, 12}},
		{"ab\nc", {0, 4}, 2, {{0, 0, 20, 10}, {0, 12, 10, 10}}, {10, 12}},
		{"ab\nc", {2, 2}, 2, nil, {20, 0}},
		{"ab\n", {3, 3}, 2, nil, {0, 12}},
		{"\n\n", {0, 2}, 2, nil, {0, 24}},
		{"", {0, 0}, 2, nil, {0, 0}},
		{"abc", {1, 3}, 2, {{10, 0, 20, 10}}, {30, 0}},
		{"é🙂\nc", {2, 8}, 2, {{10, 0, 10, 10}, {0, 12, 10, 10}}, {10, 12}},
		{"ab\nc", {3, 4}, 7, {{0, 17, 10, 10}}, {10, 17}},
	}
	for test, number in cases {
		rectangle_count = 0
		text_count = 0
		rl.SetTextLineSpacing(test.spacing)
		frame: ui.Layout_Builder
		ui.begin_layout(&frame, 100, 100, {direction = .vertical, alignment = {.start, .start}})
		handle := ui.field_layout(&frame, font, test.value, 10)
		resolved, failure := ui.finish_layout(&frame)
		testing.expect(t, failure == nil)
		paint: ui.Paint
		ui.begin_paint(&paint, resolved)
		testing.expect(t, ui.paint_field(&paint, handle, {foreground = rl.BLACK, cursor = true, selection = test.selection}))
		ui.end_paint(&paint)
		origin := text_origin
		underline := 0 if number == 5 || number == 6 else 1
		testing.expect(t, rectangle_count == len(test.highlights) + 1 + underline, "Unexpected overlay count")
		for relative, index in test.highlights {
			expected := rl.Rectangle{relative.x + origin.x, relative.y + origin.y, relative.width, relative.height}
			actual := rectangles[index]
			testing.expect(t, actual == expected, "Overlay must match its measured line")
		}
		expected := rl.Rectangle{origin.x + test.caret.x, origin.y + test.caret.y, 1, 10}
		actual := rectangles[rectangle_count - 1]
		testing.expect(t, actual == expected, "Overlay must match its measured line")
	}
}

// Paint owns no geometry and allocates no frame or scratch memory.
@(test)
paint_is_ordered_read_only_and_reuses_prepared_text :: proc(t: ^testing.T) {
	font := monospace_font()
	buffer: [65536]u8
	arena: mem.Arena
	mem.arena_init(&arena, buffer[:])
	storage: [8]ui.Layout_Node
	builder: ui.Layout_Builder
	root := ui.begin_layout(&builder, 100, 80, {direction = .vertical, alignment = {.start, .start}}, mem.arena_allocator(&arena), storage[:])
	label := ui.paragraph_layout(&builder, font, "one two three", 10)
	button := ui.button_layout(&builder, font, "Click", 10, {path = "stable"})
	resolved, failure := ui.finish_layout(&builder)
	testing.expect(t, failure == nil)
	before := storage
	// A measurement during paint would now produce completely different geometry.
	for &glyph in font.glyphs[:font.glyphCount] {glyph.advanceX = 1000}
	paint: ui.Paint
	ui.begin_paint(&paint, resolved)
	rounded_count, rectangle_count, text_count = 0, 0, 0
	testing.expect(t, ui.paint_box(&paint, root, {background = rl.BLUE}))
	testing.expect(t, ui.paint_button(&paint, button, {background = rl.RED, foreground = rl.WHITE, focus = rl.BLUE}))
	testing.expect(t, rounded_count == 2, "Exactly one fill per box/button")
	testing.expect(t, ui.paint_text(&paint, label, {rl.WHITE}))
	text_count = 0
	testing.expect(t, ui.paint_text(&paint, label, {rl.RED}))
	testing.expect(t, text_origin.x == storage[label.index].rect.x, "Prepared paragraph origin changed")
	ui.end_paint(&paint)
	for node, index in storage[:builder.frame.count] {
		testing.expect_value(t, node.rect, before[index].rect)
		testing.expect_value(t, node.clip, before[index].clip)
		testing.expect_value(t, node.style, before[index].style)
		testing.expect(t, node.content == before[index].content)
	}
	// Explicit command order wins over tree order.
	ui.begin_paint(&paint, resolved)
	rectangle_count = 0
	testing.expect(t, ui.paint_bar(&paint, button, {0.5, rl.RED, rl.BLUE}))
	testing.expect(t, ui.paint_bar(&paint, root, {1, rl.GREEN, rl.WHITE}))
	testing.expect_value(t, paint_colors[0], rl.BLUE)
	testing.expect_value(t, paint_colors[1], rl.RED)
	testing.expect_value(t, paint_colors[2], rl.WHITE)
	testing.expect_value(t, paint_colors[3], rl.GREEN)
	ui.end_paint(&paint)
}

@(test)
paint_rejects_invalid_cross_frame_and_stale_handles :: proc(t: ^testing.T) {
	builder, other: ui.Layout_Builder
	storage, other_storage: [2]ui.Layout_Node
	handle := ui.begin_layout(&builder, 20, 20, storage = storage[:])
	resolved, failure := ui.finish_layout(&builder)
	testing.expect(t, failure == nil)
	other_handle := ui.begin_layout(&other, 20, 20, storage = other_storage[:])
	paint: ui.Paint
	ui.begin_paint(&paint, resolved)
	testing.expect(t, !ui.paint_box(&paint, {}, {}))
	testing.expect(t, !ui.paint_box(&paint, other_handle, {}))
	out_of_range := handle
	out_of_range.index = len(storage)
	testing.expect(t, !ui.paint_box(&paint, out_of_range, {}))
	testing.expect(t, !ui.set_geometry(&builder, handle, {width = ui.fixed(1)}))
	ui.begin_layout(&builder, 20, 20, storage = storage[:])
	testing.expect(t, !ui.paint_box(&paint, handle, {}))
	testing.expect(t, !ui.contains_resolved(resolved, handle, {10, 10}))
	ui.end_paint(&paint)
	ui.begin_paint(&paint, {})
	ui.end_paint(&paint)
	testing.expect(t, !ui.paint_box(&paint, handle, {}))
}

@(test)
paint_uses_resolved_clip_and_fractional_dpi :: proc(t: ^testing.T) {
	builder: ui.Layout_Builder
	storage: [4]ui.Layout_Node
	ui.begin_layout(&builder, 40, 20, {direction = .vertical, alignment = {.start, .start}}, storage = storage[:])
	ui.column_layout(&builder, {width = ui.fixed(30), height = ui.fixed(10), scroll = true, scroll_offset = 5, alignment = {.start, .start}})
	handle := ui.box_layout(&builder, {width = ui.fixed(30), height = ui.fixed(30)})
	ui.close_layout(&builder)
	resolved, failure := ui.finish_layout(&builder)
	testing.expect(t, failure == nil)
	paint: ui.Paint
	ui.begin_paint(&paint, resolved, 1.5)
	testing.expect(t, ui.paint_box(&paint, handle, {}))
	testing.expect_value(t, clip_bounds, {0, 0, 45, 15})
	testing.expect(t, !ui.contains_resolved(resolved, handle, {15, 15}))
	ui.end_paint(&paint)
}

@(test)
reusable_storage_bounds_allocations_and_peak_memory :: proc(t: ^testing.T) {
	font := monospace_font()
	buffer: [65536]u8
	arena: mem.Arena
	mem.arena_init(&arena, buffer[:])
	tracking: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking, mem.arena_allocator(&arena))
	defer mem.tracking_allocator_destroy(&tracking)
	allocator := mem.tracking_allocator(&tracking)
	context.temp_allocator = allocator
	storage: [8]ui.Layout_Node
	builder: ui.Layout_Builder
	first_count, first_peak: i64
	for frame in 0 ..< 32 {
		free_all(allocator)
		start := tracking.total_allocation_count
		ui.begin_layout(&builder, 100, 100, {direction = .vertical}, allocator, storage[:])
		label := ui.paragraph_layout(&builder, font, "one two three", 10)
		field := ui.field_layout(&builder, font, "café", 10)
		resolved, failure := ui.finish_layout(&builder)
		testing.expect(t, failure == nil)
		count := tracking.total_allocation_count - start
		again, repeated_failure := ui.finish_layout(&builder)
		testing.expect(t, repeated_failure == nil && again == resolved)
		testing.expect(t, tracking.total_allocation_count - start == count, "Repeated finish remeasured")
		peak := tracking.current_memory_allocated
		before := arena.offset
		paint: ui.Paint
		ui.begin_paint(&paint, resolved)
		for color in ([2]rl.Color{rl.WHITE, rl.RED}) {
			rectangle_count, text_count = 0, 0
			ui.paint_text(&paint, label, {color})
			ui.paint_field(&paint, field, {foreground = color, cursor = true, selection = {0, 5}})
		}
		ui.end_paint(&paint)
		testing.expect(t, tracking.total_allocation_count - start == count, "Paint allocated or remeasured")
		testing.expect(t, arena.offset == before, "Paint used arena memory")
		if frame == 0 {first_count, first_peak = count, peak}
		testing.expect(t, count == first_count && peak == first_peak, "Reusable frame cost grew")
		testing.expect(t, arena.peak_used < len(buffer), "Frame exhausted reusable arena")
	}
	fmt.printf( "Reusable frame: %d allocations, %d arena bytes peak; paint: zero allocations", first_count, arena.peak_used)
}

monospace_font :: proc() -> rl.Font {
	glyphs := make([]rl.GlyphInfo, 256, context.temp_allocator)
	recs := make([]rl.Rectangle, 256, context.temp_allocator)
	for &glyph, index in glyphs {glyph.value = rune(index); glyph.advanceX = 10; recs[index].width = 10}
	return {texture = {id = 1}, baseSize = 10, glyphCount = 256, glyphs = raw_data(glyphs), recs = raw_data(recs)}
}
