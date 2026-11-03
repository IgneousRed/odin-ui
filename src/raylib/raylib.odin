package raylib_ui

import layout "../layout"
import text_core "../text"
import "core:c"
import "core:math"
import "core:mem"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"

NODE_CAPACITY :: layout.NODE_CAPACITY
INVALID_LAYOUT_INDEX :: layout.INVALID_INDEX
Layout_Rect :: layout.Rect
Layout_Unbalanced :: layout.Unbalanced
Layout_Failure :: layout.Failure
Style :: layout.Style(rl.Color)
Size :: layout.Size
Trigger :: layout.Trigger
UI :: layout.Frame(Layout_Content, rl.Color)
Node :: layout.Node(Layout_Content, rl.Color)
HSL :: struct {hue, saturation, lightness: f32}
Layout_Text :: struct {
    value: string,
    font: rl.Font,
    pixel_size: f32,
    color: rl.Color,
    centered, wrap: bool,
    wrapped_lines: []string,
}
Layout_Bar :: struct {value: f32, color: rl.Color}
Layout_Content :: union {Layout_Text, Layout_Button, Layout_Bar}
Text_Options :: struct {width, height: Size}
Button_Options :: struct {width, height: Size, pressed: bool}
Field_Options :: struct {
    width, height: Size,
    pressed, cursor: bool,
    selection: text_core.Selection,
    selection_background: rl.Color,
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

BACKGROUND_CORNER_SEGMENTS :: 8
TEXT_LINE_GAP :: f32(6)
SCROLLBAR_INSET :: f32(4)
SCROLLBAR_WIDTH :: f32(3)
SCROLLBAR_MIN_THUMB :: f32(20)
TEXT_PADDING_DIVISOR :: f32(8)
BUTTON_RADIUS_DIVISOR :: f32(4)
CORNER_SEGMENT_DIVISOR :: f32(2)
MAX_CORNER_SEGMENTS :: 128
BORDER_WIDTH :: f32(1)
BORDER_INSET :: BORDER_WIDTH / 2
LUMINANCE_RED_WEIGHT :: f32(0.2126)
LUMINANCE_GREEN_WEIGHT :: f32(0.7152)
LUMINANCE_BLUE_WEIGHT :: f32(0.0722)
LUMINANCE_THRESHOLD :: f32(0.5)
COLOR_CHANNEL_MAX :: f32(255)
HSL_SECTOR_DEGREES :: f32(60)

begin :: proc(ui: ^UI, width, height: f32, style: Style = {}, allocator: mem.Allocator = context.temp_allocator, storage: []Node = nil) {
    layout.begin(ui, width, height, style, allocator, storage)
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
            node.intrinsic.y = f32(len(content.wrapped_lines)) * (content.pixel_size + TEXT_LINE_GAP) - TEXT_LINE_GAP
        }
    }
    if !wrapped {return nil}
    ui.resolved = false
    return layout.finish(ui)
}
contains :: proc(ui: ^UI, index: int, point: rl.Vector2) -> bool {
    return layout.contains(ui, index, {point.x, point.y})
}
rounded_rect_contains :: proc(point: rl.Vector2, rect: Layout_Rect, radius: f32) -> bool {
    return layout.rounded_contains({point.x, point.y}, rect, radius)
}
text :: proc(ui: ^UI, font: rl.Font, value: string, pixel_size: f32, color: rl.Color, options: Text_Options = {}) -> int {
    size := measure_text(font, value, pixel_size)
    width, height := options.width, options.height
    if width == nil {width = fixed(size.x)}
    if height == nil {height = fixed(max(pixel_size, size.y))}
    index := layout_leaf(ui, {width = width, height = height})
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
text_lines :: proc(content: Layout_Text, width: f32, allocator: mem.Allocator = context.temp_allocator) -> []string {
    font := content.font
    return text_core.lines(content.value, width, content.pixel_size, measure_for_wrap, &font, allocator)
}
@(private)
measure_for_wrap :: proc(value: string, pixel_size: f32, data: rawptr) -> layout.Vec2 {
    size := measure_text((^rl.Font)(data)^, value, pixel_size)
    return {size.x, size.y}
}
fit_text :: proc(font: rl.Font, value: string, pixel_size, width: f32, suffix: string = "...") -> string {
    measured_font := font
    return text_core.fit(value, pixel_size, width, suffix, measure_for_wrap, &measured_font)
}
space :: proc(ui: ^UI) -> int {return layout_leaf(ui, {width = grow(), height = grow()})}

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

hsl :: proc(hue, saturation, lightness: f32) -> rl.Color {
	chroma := (1 - math.abs(2 * lightness - 1)) * saturation
	sector := hue / HSL_SECTOR_DEGREES
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
	return {
		u8((red + match) * COLOR_CHANNEL_MAX),
		u8((green + match) * COLOR_CHANNEL_MAX),
		u8((blue + match) * COLOR_CHANNEL_MAX),
		u8(COLOR_CHANNEL_MAX),
	}
}

hsl_blend :: proc(from, to: rl.Color, amount: f32) -> rl.Color {
	start, end := color_hsl(from), color_hsl(to)
	if start.saturation == 0 do start.hue = end.hue
	if end.saturation == 0 do end.hue = start.hue
	delta := math.mod(end.hue - start.hue + 540, 360) - 180
	return hsl(math.mod(start.hue + delta * amount + 360, 360), start.saturation + (end.saturation - start.saturation) * amount, start.lightness + (end.lightness - start.lightness) * amount)
}

text_pixels :: proc(point: f32) -> f32 {
	return math.pow(f32(2), point / 2)
}

control_padding :: proc(pixel_size: f32) -> f32 {
	return pixel_size / TEXT_PADDING_DIVISOR
}

control_width :: proc(text_width, pixel_size: f32) -> f32 {
	return text_width + control_padding(pixel_size) * 2
}

control_height :: proc(pixel_size: f32) -> f32 {
	return pixel_size + control_padding(pixel_size) * 2
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
	resolved_width := options.width
	resolved_height := options.height
	if resolved_width == nil do resolved_width = fixed(control_width(size.x, pixel_size))
	if resolved_height == nil do resolved_height = fixed(max(pixel_size, size.y) + control_padding(pixel_size) * 2)
	index := layout_leaf(ui, {width = resolved_width, height = resolved_height, radius = button_radius(pixel_size)})
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

@(private)
raylib_rect :: proc(rect: Layout_Rect) -> rl.Rectangle {
	return {rect.x, rect.y, rect.width, rect.height}
}

begin_clip :: proc(ui: ^UI, index: int, scale: f32 = 1) -> bool {
    if !ui.resolved || index < 0 || index >= ui.count {return false}
    node := &ui.nodes[index]
    clip := intersection(node.clip, node.rect)
    pixels := layout.pixel_bounds(clip, scale)
    if pixels.width <= 0 || pixels.height <= 0 {return false}
    scissor_min := f32(min(i32))
    // The positive i32 limit is exclusive and exactly representable as f32.
    scissor_limit := -scissor_min
    for value in ([6]f32{pixels.x, pixels.y, pixels.width, pixels.height, pixels.x + pixels.width, pixels.y + pixels.height}) {
        if value < scissor_min || value >= scissor_limit {return false}
    }
    rl.BeginScissorMode(i32(pixels.x), i32(pixels.y), i32(pixels.width), i32(pixels.height))
    return true
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
			if selection.anchor != selection.cursor || content.cursor {
				// Measuring a newline follows raylib's current global line spacing.
				line_step := measure_text(content.font, "\n", content.pixel_size).y - content.pixel_size
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
        horizontal := style.direction == .horizontal
        extent := node.rect.width if horizontal else node.rect.height
        track := max(0, extent - 2 * SCROLLBAR_INSET)
        thumb := min(track, max(SCROLLBAR_MIN_THUMB, track * track / (track + node.max_scroll)))
        offset := SCROLLBAR_INSET + (track - thumb) * clamp(style.scroll_offset / node.max_scroll, 0, 1)
        bounds := rl.Rectangle{node.rect.x + node.rect.width - SCROLLBAR_INSET, node.rect.y + offset, SCROLLBAR_WIDTH, thumb}
        if horizontal {bounds = {node.rect.x + offset, node.rect.y + node.rect.height - SCROLLBAR_INSET, thumb, SCROLLBAR_WIDTH}}
        rl.DrawRectangleRec(bounds, style.scroll_color)
        rl.EndScissorMode()
    }
}

bar :: proc(ui: ^UI, value, height: f32, color, background: rl.Color) {
    index := layout_leaf(ui, {width = grow(), height = fixed(height), background = background})
    if index >= 0 {ui.nodes[index].content = Layout_Bar{clamp(value, 0, 1), color}}
}
