package raylib_ui

// -------------------------------- Imports --------------------------------

// ---------------- Vendor ----------------

import rl "vendor:raylib"

// ---------------- Odin ----------------

import "core:c"
import "core:math"
import "core:mem"
import "core:strings"
import "core:unicode/utf8"

// ---------------- Project ----------------

import input "../input"
import layout "../layout"
import text_core "../text"

// -------------------------------- Constants --------------------------------

// ---------------- Public ----------------

NODE_CAPACITY :: layout.NODE_CAPACITY

INVALID_LAYOUT_INDEX :: layout.INVALID_INDEX

BACKGROUND_CORNER_SEGMENTS :: 8

TEXT_LINE_GAP :: f32(6)

SCROLLBAR_INSET :: f32(4)

SCROLLBAR_WIDTH :: f32(3)

SCROLLBAR_MIN_THUMB :: f32(20)

TEXT_PADDING_DIVISOR :: f32(8)

BUTTON_RADIUS_DIVISOR :: f32(4)

CORNER_SEGMENT_DIVISOR :: f32(2)

MAX_CORNER_SEGMENTS :: 128

BORDER_INSET :: BORDER_WIDTH / 2

BORDER_WIDTH :: f32(1)

LUMINANCE_RED_WEIGHT :: f32(0.2126)

LUMINANCE_GREEN_WEIGHT :: f32(0.7152)

LUMINANCE_BLUE_WEIGHT :: f32(0.0722)

LUMINANCE_THRESHOLD :: f32(0.5)

COLOR_CHANNEL_MAX :: f32(255)

HSL_SECTOR_DEGREES :: f32(60)

// -------------------------------- Types --------------------------------

// ---------------- Public ----------------

// Normal two-pass API. The legacy UI/Style builders below remain compatible.
// Keep a builder in place; handles and resolved views borrow its identity and storage.
Paint :: struct {resolved: Resolved_Layout, scale: f32, active: bool}

Resolved_Layout :: struct {owner: ^Layout_Builder, generation: u64}

Node_Handle :: struct {owner: ^Layout_Builder, generation: u64, index: int}

Layout_Builder :: struct {
	frame: layout.Frame(^Prepared_Text, No_Color),
	generation: u64,
}

Layout_Node :: layout.Node(^Prepared_Text, No_Color)

// No appearance values occupy geometry storage.
No_Color :: struct {}

Geometry :: struct {
	direction: layout.Direction,
	width, height: Size,
	padding: layout.Padding,
	gap: f32,
	alignment: layout.Alignment,
	radius: f32,
	clip_content, scroll: bool,
	scroll_offset: f32,
}

Resolved_Node :: struct {
	rect, clip: Layout_Rect,
	max_scroll, radius: f32,
	trigger: Trigger,
	first_child: int,
}

Box_Paint :: struct {background, border, focus: rl.Color}

Text_Paint :: struct {color: rl.Color}

Button_Paint :: struct {
	background, foreground, border, focus: rl.Color,
}

Field_Paint :: struct {
	background, foreground, border, focus, selection_background: rl.Color,
	selection: text_core.Selection,
	cursor: bool,
}

Bar_Paint :: struct {value: f32, color, background: rl.Color}

// Text and font resources must remain alive through paint and presented-frame input.
Prepared_Text :: struct {
	value: string,
	font: rl.Font,
	pixel_size: f32,
	wrap, centered, control, field: bool,
	extent: rl.Vector2,
	lines: []Prepared_Line,
	positions: []rl.Vector2,
}

Prepared_Line :: struct {
	runes: []rune,
	width, y: f32,
	start, end: int,
}

UI :: layout.Frame(Layout_Content, rl.Color)

Node :: layout.Node(Layout_Content, rl.Color)

Layout_Content :: union {Layout_Text, Layout_Button, Layout_Bar}

Layout_Text :: struct {
	value: string,
	font: rl.Font,
	pixel_size: f32,
	color: rl.Color,
	centered, wrap: bool,
	wrapped_lines: []string,
}

Layout_Button :: struct {
	value: string,
	font: rl.Font,
	pixel_size: f32,
	background, pressed_background: rl.Color,
	selection_background: rl.Color,
	pressed: bool,
	underline, cursor: bool,
	selection: text_core.Selection,
}

Layout_Bar :: struct {value: f32, color: rl.Color}

Text_Options :: struct {width, height: Size}

Button_Options :: struct {width, height: Size, pressed: bool}

Field_Options :: struct {
	width, height: Size,
	pressed, cursor: bool,
	selection: text_core.Selection,
	selection_background: rl.Color,
}

Style :: layout.Style(rl.Color)

Size :: layout.Size

Trigger :: layout.Trigger

HSL :: struct {hue, saturation, lightness: f32}

Layout_Rect :: layout.Rect

Layout_Unbalanced :: layout.Unbalanced

Layout_Failure :: layout.Failure

// -------------------------------- Procedures --------------------------------

// ---------------- Public ----------------

begin_layout :: proc(builder: ^Layout_Builder, width, height: f32, geometry: Geometry = {}, allocator: mem.Allocator = context.temp_allocator, storage: []Layout_Node = nil) -> Node_Handle {
	assert(builder.generation < max(u64), "Layout generation exhausted")
	builder.generation += 1
	layout.begin(&builder.frame, width, height, geometry_style(geometry), allocator, storage)
	return {builder, builder.generation, 0}
}

row_layout :: proc(builder: ^Layout_Builder, geometry: Geometry = {}) -> Node_Handle {
	value := geometry
	value.direction = .horizontal
	return {builder, builder.generation, layout.open(&builder.frame, geometry_style(value))}
}

column_layout :: proc(builder: ^Layout_Builder, geometry: Geometry = {}) -> Node_Handle {
	value := geometry
	value.direction = .vertical
	return {builder, builder.generation, layout.open(&builder.frame, geometry_style(value))}
}

close_layout :: proc(builder: ^Layout_Builder) {layout.close(&builder.frame)}

// Geometry can be revised during declaration, never through a resolved view.
set_geometry :: proc(builder: ^Layout_Builder, handle: Node_Handle, geometry: Geometry) -> bool {
	if handle.owner != builder || handle.generation != builder.generation || handle.index < 0 || handle.index >= builder.frame.count || builder.frame.resolved || builder.frame.failure != nil {return false}
	// Validate using the same gate as construction without adding a node.
	probe: layout.Frame(^Prepared_Text, No_Color)
	nodes: [1]Layout_Node
	layout.begin(&probe, 0, 0, geometry_style(geometry), storage = nodes[:])
	if probe.failure != nil {return false}
	builder.frame.nodes[handle.index].style = geometry_style(geometry)
	return true
}

text_layout :: proc(builder: ^Layout_Builder, font: rl.Font, value: string, pixel_size: f32, options: Text_Options = {}) -> Node_Handle {
	return measured_layout(builder, font, value, pixel_size, options, false, false, false, true)
}

paragraph_layout :: proc(builder: ^Layout_Builder, font: rl.Font, value: string, pixel_size: f32, centered: bool = false, width: Size = layout.Grow{}) -> Node_Handle {
	return measured_layout(builder, font, value, pixel_size, {width = width}, true, false, false, centered)
}

button_layout :: proc(builder: ^Layout_Builder, font: rl.Font, value: string, pixel_size: f32, trigger: Trigger = {}, options: Text_Options = {}) -> Node_Handle {
	handle := measured_layout(builder, font, value, pixel_size, options, false, true, false, true)
	layout_action(builder, handle, trigger)
	return handle
}

field_layout :: proc(builder: ^Layout_Builder, font: rl.Font, value: string, pixel_size: f32, trigger: Trigger = {}, options: Text_Options = {}) -> Node_Handle {
	handle := measured_layout(builder, font, value, pixel_size, options, false, true, true, true)
	layout_action(builder, handle, trigger)
	return handle
}

bar_layout :: proc(builder: ^Layout_Builder, height: f32) -> Node_Handle {
	return box_layout(builder, {width = grow(), height = fixed(height)})
}

separator_layout :: proc(builder: ^Layout_Builder, width: f32 = 1) -> Node_Handle {
	if builder.frame.depth == 0 {return box_layout(builder)}
	direction := builder.frame.nodes[builder.frame.stack[builder.frame.depth - 1].index].style.direction
	return box_layout(builder, {width = grow() if direction == .vertical else fixed(width), height = fixed(width) if direction == .vertical else grow()})
}

space_layout :: proc(builder: ^Layout_Builder) -> Node_Handle {
	return box_layout(builder, {width = grow(), height = grow()})
}

box_layout :: proc(builder: ^Layout_Builder, geometry: Geometry = {}, intrinsic: layout.Vec2 = {}) -> Node_Handle {
	return {builder, builder.generation, layout.leaf(&builder.frame, geometry_style(geometry), intrinsic)}
}

layout_action :: proc(builder: ^Layout_Builder, handle: Node_Handle, trigger: Trigger) -> bool {
	if handle.owner != builder || handle.generation != builder.generation || handle.index < 0 || handle.index >= builder.frame.count || builder.frame.resolved || builder.frame.failure != nil {return false}
	layout.action(&builder.frame, handle.index, trigger)
	return true
}

measure_layout_width :: proc(builder: ^Layout_Builder, handle: Node_Handle) -> f32 {
	if handle.owner != builder || handle.generation != builder.generation || handle.index < 0 || handle.index >= builder.frame.count {return 0}
	return layout.measure_width(&builder.frame, handle.index)
}

finish_layout :: proc(builder: ^Layout_Builder) -> (resolved: Resolved_Layout, failure: Layout_Failure) {
	frame := &builder.frame
	if frame.resolved {return {builder, builder.generation}, frame.failure}
	if failure = layout.finish(frame); failure != nil {return}
	// Width resolution is independent of intrinsic height in the portable engine.
	// Resolve widths, prepare wrapping, then resolve the resulting heights once.
	wrapped := false
	for &node in frame.nodes[:frame.count] {
		content := node.content
		if content == nil || !content.wrap {continue}
		wrapped = true
		font := content.font
		lines := text_core.lines(content.value, node.rect.width, content.pixel_size, measure_for_wrap, &font, frame.allocator)
		content.lines = make([]Prepared_Line, len(lines), frame.allocator)
		for line, index in lines {
			content.lines[index] = {runes = utf8.string_to_runes(line, frame.allocator), width = measure_text(font, line, content.pixel_size).x, y = f32(index) * (content.pixel_size + TEXT_LINE_GAP)}
		}
		node.intrinsic.y = f32(len(lines)) * content.pixel_size + f32(max(0, len(lines) - 1)) * TEXT_LINE_GAP
	}
	if wrapped {
		frame.resolved = false
		if failure = layout.finish(frame); failure != nil {return}
	}
	for &node in frame.nodes[:frame.count] {
		content := node.content
		if content == nil || content.wrap {continue}
		line_count := 1 + strings.count(content.value, "\n")
		content.lines = make([]Prepared_Line, line_count, frame.allocator)
		step := measure_text(content.font, "\n", content.pixel_size).y - content.pixel_size
		start, line_index := 0, 0
		field_scale: f32
		if content.field && content.font.texture.id != 0 && rl.IsFontValid(content.font) {field_scale = content.pixel_size / f32(content.font.baseSize)}
		if content.field {content.positions = make([]rl.Vector2, len(content.value) + 1, frame.allocator)}
		for end in 0 ..= len(content.value) {
			if end < len(content.value) && content.value[end] != '\n' {continue}
			line := content.value[start:end]
			content.lines[line_index] = {utf8.string_to_runes(line, frame.allocator), measure_text(content.font, line, content.pixel_size).x, f32(line_index) * step, start, end}
			if content.field {
				// Match raylib's zero-spacing advance rule, accumulating font units
				// before scaling. Measuring every prefix would cost quadratic memory.
				advance: f32
				for codepoint, offset in line {
					content.positions[start + offset] = {advance * field_scale, f32(line_index) * step}
					if field_scale != 0 {
						glyph_index := rl.GetGlyphIndex(content.font, codepoint)
						glyph := content.font.glyphs[glyph_index]
						advance += f32(glyph.advanceX) if glyph.advanceX > 0 else content.font.recs[glyph_index].width + f32(glyph.offsetX)
					}
				}
				content.positions[end] = {content.lines[line_index].width, f32(line_index) * step}
			}
			start, line_index = end + 1, line_index + 1
		}
	}
	return {builder, builder.generation}, nil
}

begin_paint :: proc(paint: ^Paint, resolved: Resolved_Layout, scale: f32 = 1) {
	paint^ = {resolved, scale, true}
}

end_paint :: proc(paint: ^Paint) {paint.active = false}

paint_box :: proc(paint: ^Paint, handle: Node_Handle, appearance: Box_Paint) -> bool {
	node, ok := geometry(paint.resolved, handle)
	if !paint.active || !ok {return false}
	if !paint_clip(paint, node) {return true}
	defer rl.EndScissorMode()
	draw_paint_box(node, appearance)
	return true
}

paint_text :: proc(paint: ^Paint, handle: Node_Handle, appearance: Text_Paint) -> bool {
	node, ok := geometry(paint.resolved, handle)
	if !paint.active || !ok {return false}
	content := paint.resolved.owner.frame.nodes[handle.index].content
	if content == nil {return false}
	if !paint_clip(paint, node) {return true}
	defer rl.EndScissorMode()
	draw_prepared_text(content, node.rect, appearance.color)
	return true
}

paint_button :: proc(paint: ^Paint, handle: Node_Handle, appearance: Button_Paint) -> bool {
	node, ok := geometry(paint.resolved, handle)
	if !paint.active || !ok {return false}
	content := paint.resolved.owner.frame.nodes[handle.index].content
	if content == nil || !content.control || content.field {return false}
	if !paint_clip(paint, node) {return true}
	defer rl.EndScissorMode()
	draw_paint_box(node, {appearance.background, appearance.border, appearance.focus})
	draw_prepared_text(content, node.rect, appearance.foreground)
	return true
}

paint_field :: proc(paint: ^Paint, handle: Node_Handle, appearance: Field_Paint) -> bool {
	node, ok := geometry(paint.resolved, handle)
	if !paint.active || !ok {return false}
	content := paint.resolved.owner.frame.nodes[handle.index].content
	if content == nil || !content.field {return false}
	if !paint_clip(paint, node) {return true}
	defer rl.EndScissorMode()
	draw_paint_box(node, {appearance.background, appearance.border, appearance.focus})
	anchor := text_boundary(content.value, appearance.selection.anchor)
	cursor := text_boundary(content.value, appearance.selection.cursor)
	origin := rl.Vector2{node.rect.x + (node.rect.width - content.extent.x) / 2, node.rect.y + (node.rect.height - content.extent.y) / 2}
	padding := min(control_padding(content.pixel_size), max(0, (node.rect.width - BORDER_WIDTH) / 2))
	left := node.rect.x + padding
	right := max(left, node.rect.x + node.rect.width - padding - BORDER_WIDTH)
	cursor_x := origin.x + content.positions[cursor].x
	origin.x += clamp(cursor_x, left, right) - cursor_x
	overlay_y := node.rect.y + (node.rect.height - max(content.pixel_size, content.extent.y)) / 2
	first, last := min(anchor, cursor), max(anchor, cursor)
	for line in content.lines {
		start, end := max(first, line.start), min(last, line.end)
		if start < end {rl.DrawRectangleRec({origin.x + content.positions[start].x, overlay_y + line.y, content.positions[end].x - content.positions[start].x, content.pixel_size}, appearance.selection_background)}
		rl.DrawTextCodepoints(content.font, raw_data(line.runes), c.int(len(line.runes)), {origin.x, origin.y + line.y}, content.pixel_size, 0, appearance.foreground)
	}
	if node.rect.width > control_padding(content.pixel_size) * 2 {
		rl.DrawRectangleRec({node.rect.x + control_padding(content.pixel_size), node.rect.y + node.rect.height - BORDER_WIDTH - control_padding(content.pixel_size), node.rect.width - control_padding(content.pixel_size) * 2, BORDER_WIDTH}, appearance.foreground)
	}
	if appearance.cursor {rl.DrawRectangleRec({origin.x + content.positions[cursor].x, overlay_y + content.positions[cursor].y, BORDER_WIDTH, content.pixel_size}, appearance.foreground)}
	return true
}

paint_bar :: proc(paint: ^Paint, handle: Node_Handle, appearance: Bar_Paint) -> bool {
	node, ok := geometry(paint.resolved, handle)
	if !paint.active || !ok {return false}
	if !paint_clip(paint, node) {return true}
	defer rl.EndScissorMode()
	rl.DrawRectangleRec(raylib_rect(node.rect), appearance.background)
	rl.DrawRectangleRec({node.rect.x, node.rect.y, node.rect.width * clamp(appearance.value, 0, 1), node.rect.height}, appearance.color)
	return true
}

paint_scrollbar :: proc(paint: ^Paint, handle: Node_Handle, color: rl.Color) -> bool {
	node, ok := geometry(paint.resolved, handle)
	if !paint.active || !ok {return false}
	style := paint.resolved.owner.frame.nodes[handle.index].style
	if !style.scroll || node.max_scroll <= 0 || color.a == 0 || !paint_clip(paint, node) {return true}
	defer rl.EndScissorMode()
	rl.DrawRectangleRec(scrollbar_bounds(node.rect, style.direction == .horizontal, node.max_scroll, style.scroll_offset), color)
	return true
}

hit_resolved :: proc(resolved: Resolved_Layout, point: rl.Vector2) -> Trigger {
	if layout_count(resolved) == 0 {return {}}
	return layout.hit(&resolved.owner.frame, {point.x, point.y})
}

layout_text :: proc(resolved: Resolved_Layout, handle: Node_Handle) -> (value: string, centered: bool, ok: bool) {
	if _, valid := geometry(resolved, handle); !valid {return}
	content := resolved.owner.frame.nodes[handle.index].content
	if content == nil {return}
	return content.value, content.centered, true
}

contains_resolved :: proc(resolved: Resolved_Layout, handle: Node_Handle, point: rl.Vector2) -> bool {
	node, ok := geometry(resolved, handle)
	return ok && rounded_rect_contains(point, node.clip, 0) && rounded_rect_contains(point, node.rect, node.radius)
}

layout_handle :: proc(resolved: Resolved_Layout, index: int) -> Node_Handle {
	if index < 0 || index >= layout_count(resolved) {return {}}
	return {resolved.owner, resolved.generation, index}
}

geometry :: proc(resolved: Resolved_Layout, handle: Node_Handle) -> (node: Resolved_Node, ok: bool) {
	if handle.owner != resolved.owner || handle.generation != resolved.generation || handle.index < 0 || handle.index >= layout_count(resolved) {return}
	value := &resolved.owner.frame.nodes[handle.index]
	return {value.rect, value.clip, value.max_scroll, value.style.radius, value.trigger, value.first_child}, true
}

layout_count :: proc(resolved: Resolved_Layout) -> int {
	if resolved.owner == nil || resolved.generation != resolved.owner.generation || !resolved.owner.frame.resolved || resolved.owner.frame.failure != nil {return 0}
	return resolved.owner.frame.count
}

draw :: proc(ui: ^UI, scale: f32 = 1) {
	if ui.count == 0 && ui.failure == nil {return}
	assert(ui.failure == nil && ui.resolved)
	for &node, index in ui.nodes[:ui.count] {
		if !begin_clip(ui, index, scale) {continue}
		// Successful clipping guarantees positive node dimensions.
		if style := node.style; style.background.a > 0 {
			if style.radius > 0 {
				rl.DrawRectangleRounded(raylib_rect(node.rect), min(1, 2 * style.radius / min(node.rect.width, node.rect.height)), BACKGROUND_CORNER_SEGMENTS, style.background)
			} else {rl.DrawRectangleRec(raylib_rect(node.rect), style.background)}
		}
		switch content in node.content {
		case nil:
		case Layout_Bar:
			rl.DrawRectangleRec({node.rect.x, node.rect.y, node.rect.width * content.value, node.rect.height}, content.color)
		case Layout_Text:
			single_line := [1]string{content.value}
			lines := content.wrapped_lines
			if !content.wrap {lines = single_line[:]}
			y := node.rect.y
			for line in lines {
				origin := rl.Vector2{node.rect.x, y}
				runes := utf8.string_to_runes(line, context.temp_allocator)
				if content.centered || !content.wrap {
					size := rl.MeasureTextCodepoints(content.font, (^c.int)(raw_data(runes)), c.int(len(runes)), content.pixel_size, 0)
					origin.x += (node.rect.width - size.x) / 2
					if !content.wrap {origin.y += (node.rect.height - size.y) / 2}
				}
				rl.DrawTextCodepoints(content.font, raw_data(runes), c.int(len(runes)), origin, content.pixel_size, 0, content.color)
				y += content.pixel_size + TEXT_LINE_GAP
			}
		case Layout_Button:
			background := content.pressed_background if content.pressed else content.background
			foreground := button_foreground(background)
			// Draw the fill and inside border before text overlays.
			box := raylib_rect(node.rect)
			radius := clamp(node.style.radius, 0, min(node.rect.width, node.rect.height) / 2)
			// Scissoring does not bound raylib's CPU tessellation; cap before conversion.
			segments := c.int(min(radius / CORNER_SEGMENT_DIVISOR + 1, f32(MAX_CORNER_SEGMENTS)))
			roundness := radius * 2 / min(node.rect.width, node.rect.height)
			rl.DrawRectangleRounded(box, roundness, segments, background)
			border_box := rl.Rectangle {
				box.x + BORDER_INSET,
				box.y + BORDER_INSET,
				box.width - BORDER_WIDTH,
				box.height - BORDER_WIDTH,
			}
			if border_box.width > 0 && border_box.height > 0 {
				border_radius := max(0, radius - BORDER_INSET)
				border_roundness := border_radius * 2 / min(border_box.width, border_box.height)
				rl.DrawRectangleRoundedLinesEx(border_box, border_roundness, segments, BORDER_WIDTH, foreground)
			}
			selection := text_core.Selection{
				anchor = text_boundary(content.value, content.selection.anchor),
				cursor = text_boundary(content.value, content.selection.cursor),
			}
			runes := utf8.string_to_runes(content.value, context.temp_allocator)
			size := rl.MeasureTextCodepoints(content.font, (^c.int)(raw_data(runes)), c.int(len(runes)), content.pixel_size, 0)
			origin := rl.Vector2{node.rect.x + (node.rect.width - size.x) / 2, node.rect.y + (node.rect.height - size.y) / 2}
			caret := rl.Rectangle{origin.x, node.rect.y + (node.rect.height - max(content.pixel_size, size.y)) / 2, BORDER_WIDTH, content.pixel_size}
			if selection.anchor != selection.cursor || content.cursor || content.underline {
				// Measuring a newline follows raylib's current global line spacing.
				line_step := measure_text(content.font, "\n", content.pixel_size).y - content.pixel_size
				if content.underline || content.cursor {
					line_start := 0
					for offset in 0 ..< selection.cursor {
						if content.value[offset] == '\n' {line_start = offset + 1}
					}
					cursor_x := origin.x + measure_text(content.font, content.value[line_start:selection.cursor], content.pixel_size).x
					padding := min(control_padding(content.pixel_size), max(0, (node.rect.width - BORDER_WIDTH) / 2))
					left := node.rect.x + padding
					right := max(left, node.rect.x + node.rect.width - padding - BORDER_WIDTH)
					// Keep the field's cursor position visible even while its caret blinks.
					origin.x += clamp(cursor_x, left, right) - cursor_x
				}
				start, end := min(selection.anchor, selection.cursor), max(selection.anchor, selection.cursor)
				line_start := 0
				y := caret.y
				for line_end in 0 ..= len(content.value) {
					if line_end < len(content.value) && content.value[line_end] != '\n' {continue}
					line := content.value[line_start:line_end]
					if selection.cursor >= line_start && selection.cursor <= line_end {
						caret.x = origin.x + measure_text(content.font, line[:selection.cursor - line_start], content.pixel_size).x
						caret.y = y
					}
					first, last := max(start, line_start), min(end, line_end)
					if first < last {
						before := measure_text(content.font, line[:first - line_start], content.pixel_size).x
						width := measure_text(content.font, line[first - line_start:last - line_start], content.pixel_size).x
						rl.DrawRectangleRec({origin.x + before, y, width, content.pixel_size}, content.selection_background)
					}
					line_start = line_end + 1
					y += line_step
				}
			}
			rl.DrawTextCodepoints(content.font, raw_data(runes), c.int(len(runes)), origin, content.pixel_size, 0, foreground)
			padding := control_padding(content.pixel_size)
			// A compressed field may have no room between its text padding.
			if content.underline && node.rect.width > padding * 2 {
				y := node.rect.y + node.rect.height - BORDER_WIDTH - padding
				rl.DrawRectangleRec({node.rect.x + padding, y, node.rect.width - padding * 2, BORDER_WIDTH}, foreground)
			}
			if content.cursor {
				rl.DrawRectangleRec(caret, foreground)
			}
		}
		rl.EndScissorMode()
	}
	for &node, index in ui.nodes[:ui.count] {
		style := node.style
		if !style.scroll || node.max_scroll <= 0 || style.scroll_color.a == 0 || !begin_clip(ui, index, scale) {continue}
		rl.DrawRectangleRec(scrollbar_bounds(node.rect, style.direction == .horizontal, node.max_scroll, style.scroll_offset), style.scroll_color)
		rl.EndScissorMode()
	}
}

field :: proc(
	ui: ^UI,
	font: rl.Font,
	value: string,
	pixel_size: f32,
	background, pressed_background: rl.Color,
	trigger: Trigger,
	options: Field_Options = {},
) -> int {
	index := button(
		ui,
		font,
		value,
		pixel_size,
		background,
		pressed_background,
		trigger,
		{width = options.width, height = options.height, pressed = options.pressed},
	)
	if index >= 0 {
		control := &ui.nodes[index].content.(Layout_Button)
		control.underline = true
		control.cursor = options.cursor
		control.selection = options.selection
		control.selection_background = options.selection_background
	}
	return index
}

button :: proc(
	ui: ^UI,
	font: rl.Font,
	value: string,
	pixel_size: f32,
	background, pressed_background: rl.Color,
	trigger: Trigger,
	options: Button_Options = {},
) -> int {
	size := measure_text(font, value, pixel_size)
	size = {control_width(size.x, pixel_size), max(pixel_size, size.y) + control_padding(pixel_size) * 2}
	resolved_width := options.width
	resolved_height := options.height
	if resolved_width == nil do resolved_width = fixed(size.x)
	if resolved_height == nil do resolved_height = fixed(size.y)
	index := layout_leaf(ui, {width = resolved_width, height = resolved_height, radius = button_radius(pixel_size)}, {size.x, size.y})
	if index >= 0 {
		ui.nodes[index].trigger = trigger
		ui.nodes[index].content = Layout_Button {
			value = strings.clone(value, ui.allocator),
			font = font,
			pixel_size = pixel_size,
			background = background,
			pressed_background = pressed_background,
			pressed = options.pressed,
		}
	}
	return index
}

scroll_column :: proc(ui: ^UI, offset: f32, style: Style = {}) -> int {
	value := style
	value.scroll, value.scroll_offset = true, offset
	return column(ui, value)
}

scroll_row :: proc(ui: ^UI, offset: f32, style: Style = {}) -> int {
	value := style
	value.scroll, value.scroll_offset = true, offset
	return row(ui, value)
}

hsl_color :: proc(value: HSL) -> rl.Color {
	return hsl(value.hue, value.saturation, value.lightness)
}

// Amount is in [0, 1]. Blend along the shorter hue arc, with linear opacity.
hsl_blend :: proc(from, to: rl.Color, amount: f32) -> rl.Color {
	start, end := color_hsl(from), color_hsl(to)
	if start.saturation == 0 do start.hue = end.hue
	if end.saturation == 0 do end.hue = start.hue
	delta := math.mod(end.hue - start.hue + 540, 360) - 180
	color := hsl(start.hue + delta * amount, start.saturation + (end.saturation - start.saturation) * amount, start.lightness + (end.lightness - start.lightness) * amount)
	color.a = u8(math.round(f32(from.a) + (f32(to.a) - f32(from.a)) * amount))
	return color
}

finish :: proc(ui: ^UI) -> Layout_Failure {
	if ui.resolved {return ui.failure}
	failure := layout.finish(ui)
	if failure != nil {return failure}
	wrapped := false
	for &node in ui.nodes[:ui.count] {
		if content, ok := node.content.(Layout_Text); ok && content.wrap {
			wrapped = true
			// Retain the derived lines for drawing; declared fit/fixed sizing stays intact.
			content.wrapped_lines = text_lines(content, node.rect.width, ui.allocator)
			node.content = content
			line_count := len(content.wrapped_lines)
			node.intrinsic.y = f32(line_count) * content.pixel_size + f32(line_count - 1) * TEXT_LINE_GAP
		}
	}
	if !wrapped {return nil}
	ui.resolved = false
	return layout.finish(ui)
}

text :: proc(ui: ^UI, font: rl.Font, value: string, pixel_size: f32, color: rl.Color, options: Text_Options = {}) -> int {
	size := measure_text(font, value, pixel_size)
	size.y = max(pixel_size, size.y)
	width, height := options.width, options.height
	if width == nil {width = fixed(size.x)}
	if height == nil {height = fixed(size.y)}
	index := layout_leaf(ui, {width = width, height = height}, {size.x, size.y})
	if index >= 0 {ui.nodes[index].content = Layout_Text{value = strings.clone(value, ui.allocator), font = font, pixel_size = pixel_size, color = color, centered = true}}
	return index
}

// Paragraphs wrap after horizontal layout has established the available width.
paragraph :: proc(ui: ^UI, font: rl.Font, value: string, pixel_size: f32, color: rl.Color, centered: bool = false, width: Size = layout.Grow{}) -> int {
	intrinsic := layout.Vec2{y = pixel_size}
	if width == nil {intrinsic.x = measure_text(font, value, pixel_size).x}
	index := layout_leaf(ui, {width = width}, intrinsic)
	if index >= 0 {ui.nodes[index].content = Layout_Text{value = strings.clone(value, ui.allocator), font = font, pixel_size = pixel_size, color = color, centered = centered, wrap = true}}
	return index
}

fit_text :: proc(font: rl.Font, value: string, pixel_size, width: f32, suffix: string = "...") -> string {
	measured_font := font
	return text_core.fit(value, pixel_size, width, suffix, measure_for_wrap, &measured_font)
}

control_width :: proc(text_width, pixel_size: f32) -> f32 {
	return text_width + control_padding(pixel_size) * 2
}

control_height :: proc(pixel_size: f32) -> f32 {
	return pixel_size + control_padding(pixel_size) * 2
}

separator :: proc(ui: ^UI, color: rl.Color, width := f32(1)) -> int {
	if ui.failure != nil || ui.depth == 0 {return layout_leaf(ui, {})}
	parent := &ui.nodes[ui.stack[ui.depth - 1].index]
	direction := parent.style.direction
	return layout_leaf(ui, Style{
		width = grow() if direction == .vertical else fixed(width),
		height = fixed(width) if direction == .vertical else grow(),
		background = color,
	})
}

bar :: proc(ui: ^UI, value, height: f32, color, background: rl.Color) {
	index := layout_leaf(ui, {width = grow(), height = fixed(height), background = background})
	if index >= 0 {ui.nodes[index].content = Layout_Bar{clamp(value, 0, 1), color}}
}

begin :: proc(ui: ^UI, width, height: f32, style: Style = {}, allocator: mem.Allocator = context.temp_allocator, storage: []Node = nil) {
	layout.begin(ui, width, height, style, allocator, storage)
}

contains :: proc(ui: ^UI, index: int, point: rl.Vector2) -> bool {
	return layout.contains(ui, index, {point.x, point.y})
}

rounded_rect_contains :: proc(point: rl.Vector2, rect: Layout_Rect, radius: f32) -> bool {
	return layout.rounded_contains({point.x, point.y}, rect, radius)
}

// Input collection is optional: custom hosts can supply the same portable Pointer directly.
pointer :: proc(previous: input.Pointer, scale: f32 = 1) -> input.Pointer {
	position := rl.GetMousePosition()
	mouse := input.Pointer{position = {position.x, position.y},
		pressed = rl.IsMouseButtonPressed(.LEFT), down = rl.IsMouseButtonDown(.LEFT),
		released = rl.IsMouseButtonReleased(.LEFT)}
	touches := make([]input.Touch, rl.GetTouchPointCount(), context.temp_allocator)
	for &touch, index in touches {
		point := rl.GetTouchPosition(i32(index))
		touch = {int(rl.GetTouchPointId(i32(index))), {point.x, point.y}}
	}
	return input.pointer(previous, mouse, touches, rl.IsWindowFocused(), scale)
}

hit :: proc(ui: ^UI, point: rl.Vector2) -> Trigger {
	return layout.hit(ui, {point.x, point.y})
}

text_lines :: proc(content: Layout_Text, width: f32, allocator: mem.Allocator = context.temp_allocator) -> []string {
	font := content.font
	return text_core.lines(content.value, width, content.pixel_size, measure_for_wrap, &font, allocator)
}

space :: proc(ui: ^UI) -> int {return layout_leaf(ui, {width = grow(), height = grow()})}

text_pixels :: proc(point: f32) -> f32 {
	return math.pow(f32(2), point / 2)
}

button_foreground :: proc(background: rl.Color) -> rl.Color {
	lightness :=
		(LUMINANCE_RED_WEIGHT * f32(background.r) +
			LUMINANCE_GREEN_WEIGHT * f32(background.g) +
			LUMINANCE_BLUE_WEIGHT * f32(background.b)) /
		COLOR_CHANNEL_MAX
	return rl.BLACK if lightness >= LUMINANCE_THRESHOLD else rl.WHITE
}

row :: proc(ui: ^UI, style: Style = {}) -> int {
	value := style
	value.direction = .horizontal
	return layout_open(ui, value)
}

column :: proc(ui: ^UI, style: Style = {}) -> int {
	value := style
	value.direction = .vertical
	return layout_open(ui, value)
}

color_hsl :: proc(color: rl.Color) -> HSL {
	r, g, b := f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255
	high, low := max(r,g,b), min(r,g,b)
	delta := high - low
	lightness := (high + low) / 2
	if delta == 0 do return {0, 0, lightness}
	hue: f32
	if high == r do hue = math.mod((g-b) / delta, 6)
	else if high == g do hue = (b-r) / delta + 2
	else do hue = (r-g) / delta + 4
	return {math.mod(hue * 60 + 360, 360), delta / (1 - math.abs(2 * lightness - 1)), lightness}
}

begin_clip :: proc(ui: ^UI, index: int, scale: f32 = 1) -> bool {
	if !ui.resolved || index < 0 || index >= ui.count {return false}
	node := &ui.nodes[index]
	return begin_scissor(intersection(node.clip, node.rect), scale)
}

control_padding :: proc(pixel_size: f32) -> f32 {
	return pixel_size / TEXT_PADDING_DIVISOR
}

button_radius :: proc(pixel_size: f32) -> f32 {
	return pixel_size / BUTTON_RADIUS_DIVISOR
}

measure_text :: proc(font: rl.Font, text: string, pixel_size: f32) -> rl.Vector2 {
	runes := utf8.string_to_runes(text, context.temp_allocator)
	return rl.MeasureTextCodepoints(
		font,
		(^c.int)(raw_data(runes)),
		c.int(len(runes)),
		pixel_size,
		0,
	)
}

// Hue wraps in degrees; saturation and lightness are in [0, 1].
hsl :: proc(hue, saturation, lightness: f32) -> rl.Color {
	chroma := (1 - math.abs(2 * lightness - 1)) * saturation
	sector := math.mod(hue, 360) / HSL_SECTOR_DEGREES
	if sector < 0 {sector += 6}
	offset := chroma * (1 - math.abs(math.mod(sector, 2) - 1))
	red, green, blue: f32
	switch {
	case sector < 1:
		red, green = chroma, offset
	case sector < 2:
		red, green = offset, chroma
	case sector < 3:
		green, blue = chroma, offset
	case sector < 4:
		green, blue = offset, chroma
	case sector < 5:
		red, blue = offset, chroma
	case:
		red, blue = chroma, offset
	}
	match := lightness - chroma / 2
	// Quantize to the nearest byte; truncation loses channels on RGB/HSL round trips.
	return {
		u8(math.round(clamp(red + match, 0, 1) * COLOR_CHANNEL_MAX)),
		u8(math.round(clamp(green + match, 0, 1) * COLOR_CHANNEL_MAX)),
		u8(math.round(clamp(blue + match, 0, 1) * COLOR_CHANNEL_MAX)),
		u8(COLOR_CHANNEL_MAX),
	}
}

fixed :: layout.fixed

grow :: layout.grow

close :: layout.close

layout_open :: layout.open

layout_leaf :: layout.leaf

intersection :: layout.intersection

measure_width :: layout.measure_width

text_boundary :: text_core.boundary

action :: layout.action

node_trigger :: layout.node_trigger

// ---------------- File ----------------

@(private="file")
measure_for_wrap :: proc(value: string, pixel_size: f32, data: rawptr) -> layout.Vec2 {
	size := measure_text((^rl.Font)(data)^, value, pixel_size)
	return {size.x, size.y}
}


@(private="file")
geometry_style :: proc(value: Geometry) -> layout.Style(No_Color) {
	return {direction = value.direction, width = value.width, height = value.height, padding = value.padding, gap = value.gap, alignment = value.alignment, radius = value.radius, clip_content = value.clip_content, scroll = value.scroll, scroll_offset = value.scroll_offset}
}

@(private="file")
measured_layout :: proc(builder: ^Layout_Builder, font: rl.Font, value: string, pixel_size: f32, options: Text_Options, wrap, control, field, centered: bool) -> Node_Handle {
	size := measure_text(font, value, pixel_size)
	size.y = max(size.y, pixel_size)
	intrinsic := layout.Vec2{size.x, size.y}
	geometry := Geometry{width = options.width, height = options.height}
	if wrap {
		intrinsic.y = pixel_size
		if options.width != nil {intrinsic.x = 0}
	} else {
		if control {
			intrinsic = {control_width(size.x, pixel_size), max(pixel_size, size.y) + control_padding(pixel_size) * 2}
			geometry.radius = button_radius(pixel_size)
		}
		if geometry.width == nil {geometry.width = fixed(intrinsic.x)}
		if geometry.height == nil {geometry.height = fixed(intrinsic.y)}
	}
	handle := box_layout(builder, geometry, intrinsic)
	if handle.index < 0 {return handle}
	content := new(Prepared_Text, builder.frame.allocator)
	content^ = {value = strings.clone(value, builder.frame.allocator), font = font, pixel_size = pixel_size, wrap = wrap, centered = centered, control = control, field = field, extent = size}
	builder.frame.nodes[handle.index].content = content
	return handle
}

@(private="file")
paint_clip :: proc(paint: ^Paint, node: Resolved_Node) -> bool {
	return begin_scissor(intersection(node.clip, node.rect), paint.scale)
}

@(private="file")
begin_scissor :: proc(clip: Layout_Rect, scale: f32) -> bool {
	pixels := layout.pixel_bounds(clip, scale)
	if pixels.width <= 0 || pixels.height <= 0 {return false}
	minimum := f32(min(i32))
	// The positive i32 limit is exclusive and exactly representable as f32.
	limit := -minimum
	for value in ([6]f32{pixels.x, pixels.y, pixels.width, pixels.height, pixels.x + pixels.width, pixels.y + pixels.height}) {
		if value < minimum || value >= limit {return false}
	}
	rl.BeginScissorMode(i32(pixels.x), i32(pixels.y), i32(pixels.width), i32(pixels.height))
	return true
}

@(private="file")
draw_paint_box :: proc(node: Resolved_Node, appearance: Box_Paint) {
	box := raylib_rect(node.rect)
	radius := clamp(node.radius, 0, min(box.width, box.height) / 2)
	segments := c.int(min(radius / CORNER_SEGMENT_DIVISOR + 1, f32(MAX_CORNER_SEGMENTS)))
	if appearance.background.a > 0 {rl.DrawRectangleRounded(box, radius * 2 / min(box.width, box.height), segments, appearance.background)}
	// Both indicators are inside the bounds. A focus ring sits inside the border.
	for color, index in ([2]rl.Color{appearance.border, appearance.focus}) {
		inset := BORDER_INSET + f32(index) * BORDER_WIDTH
		bounds := rl.Rectangle{box.x + inset, box.y + inset, box.width - inset * 2, box.height - inset * 2}
		if color.a > 0 && bounds.width > 0 && bounds.height > 0 {
			rl.DrawRectangleRoundedLinesEx(bounds, max(0, radius - inset) * 2 / min(bounds.width, bounds.height), segments, BORDER_WIDTH, color)
		}
	}
}

@(private="file")
draw_prepared_text :: proc(content: ^Prepared_Text, bounds: Layout_Rect, color: rl.Color) {
	for line in content.lines {
		origin := rl.Vector2{bounds.x, bounds.y + line.y}
		if content.centered {origin.x += (bounds.width - line.width) / 2}
		if !content.wrap {origin.y += (bounds.height - content.extent.y) / 2}
		rl.DrawTextCodepoints(content.font, raw_data(line.runes), c.int(len(line.runes)), origin, content.pixel_size, 0, color)
	}
}

@(private="file")
scrollbar_bounds :: proc(rect: Layout_Rect, horizontal: bool, maximum, scroll_offset: f32) -> rl.Rectangle {
	extent := rect.width if horizontal else rect.height
	track := max(0, extent - 2 * SCROLLBAR_INSET)
	thumb := min(track, max(SCROLLBAR_MIN_THUMB, track * track / (track + maximum)))
	offset := SCROLLBAR_INSET + (track - thumb) * clamp(scroll_offset / maximum, 0, 1)
	if horizontal {return {rect.x + offset, rect.y + rect.height - SCROLLBAR_INSET, thumb, SCROLLBAR_WIDTH}}
	return {rect.x + rect.width - SCROLLBAR_INSET, rect.y + offset, SCROLLBAR_WIDTH, thumb}
}

@(private="file")
raylib_rect :: proc(rect: Layout_Rect) -> rl.Rectangle {
	return {rect.x, rect.y, rect.width, rect.height}
}
