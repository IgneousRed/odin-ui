package showcase

// -------------------------------- Imports --------------------------------

// ---------------- Vendor ----------------

import rl "vendor:raylib"

// ---------------- Odin ----------------

import "core:fmt"
import "core:strings"

// ---------------- Project ----------------

import ui "odin_ui:raylib"
import input "odin_ui:input"
import text "odin_ui:text"

// -------------------------------- Constants --------------------------------

// ---------------- Public ----------------

FONT_SIZE :: f32(22)
WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600
CONTENT_PADDING :: f32(20)
CONTENT_GAP :: f32(12)
FONT_RASTER_SIZE :: 48
FIRST_CODEPOINT :: 32
GLYPH_COUNT :: 224
NAME_CAPACITY :: 256
NODE_CAPACITY :: 32
INITIAL_NAME :: "Edit me: café"
BACKGROUND :: rl.Color{26, 29, 36, 255}
PANEL :: rl.Color{45, 51, 64, 255}
ACCENT :: rl.Color{75, 128, 220, 255}
FONT_DATA :: #load("assets/AtkinsonHyperlegibleNext-SemiBold.ttf", []u8)

// -------------------------------- Types --------------------------------

// ---------------- Public ----------------

// Keep this instance in place after building a frame, which borrows its node array.
App :: struct {
	frame: ui.Layout_Builder,
	resolved: ui.Resolved_Layout,
	viewport: rl.Vector2,
	nodes: [NODE_CAPACITY]ui.Layout_Node,
	font: rl.Font,
	pointer: input.Pointer,
	press: input.Press,
	clicks: int,
	name: [NAME_CAPACITY]u8,
	name_length: int,
	selection: text.Selection,
	editing: bool,
	focused: int,
}

// -------------------------------- Procedures --------------------------------

// ---------------- Public ----------------

initialize :: proc() -> App {
	app: App
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odin UI")
	codepoints: [GLYPH_COUNT]rune
	for &codepoint, index in codepoints {codepoint = rune(index + FIRST_CODEPOINT)}
	app.font = rl.LoadFontFromMemory(".ttf", raw_data(FONT_DATA), i32(len(FONT_DATA)), FONT_RASTER_SIZE, raw_data(codepoints[:]), i32(len(codepoints)))
	rl.SetTextureFilter(app.font.texture, .BILINEAR)
	app.name_length = copy(app.name[:], INITIAL_NAME)
	app.selection = {app.name_length, app.name_length}
	return app
}

frame :: proc(app: ^App, width, height: f32) {
	pointer := ui.pointer(app.pointer)
	if ui.layout_count(app.resolved) > 0 && app.viewport.x == width && app.viewport.y == height {
		trigger := ui.hit_resolved(app.resolved, {pointer.position.x, pointer.position.y})
		event := input.button(&app.press, pointer, trigger.path == "count")
		if event.clicked {app.clicks += 1}
		if pointer.pressed {
			app.editing = trigger.path == "name"
			app.focused = 2 if app.editing else 1 if trigger.path == "count" else 0
		}
	} else {app.press = {}}
	app.pointer = pointer
	if rl.IsKeyPressed(.TAB) {
		app.focused = input.focus_next(app.focused, []int{1, 2}, rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT))
		app.editing = app.focused == 2
	}
	if app.focused == 1 && (rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE)) {app.clicks += 1}
	if app.editing {
		if (rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL) || rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.RIGHT_SUPER)) && rl.IsKeyPressed(.A) {edit_name(app, .select_all)}
		if rl.IsKeyPressed(.BACKSPACE) {edit_name(app, .backspace)}
		if rl.IsKeyPressed(.LEFT) {edit_name(app, .left, extend = rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT))}
		if rl.IsKeyPressed(.RIGHT) {edit_name(app, .right, extend = rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT))}
		inserted := strings.builder_make(allocator = context.temp_allocator)
		for code := rl.GetCharPressed(); code != 0; code = rl.GetCharPressed() {strings.write_rune(&inserted, code)}
		if value := strings.to_string(inserted); value != "" {edit_name(app, .insert, value)}
	}
	free_all(context.temp_allocator)
	padding := CONTENT_PADDING
	ui.begin_layout(&app.frame, width, height, {direction = .vertical, padding = {padding, padding, padding, padding}, gap = CONTENT_GAP, alignment = {.stretch, .start}}, storage = app.nodes[:])
	font := app.font
	title := ui.paragraph_layout(&app.frame, font, "Shared Odin UI", FONT_SIZE * 1.5)
	description := ui.paragraph_layout(&app.frame, font, "Resize this window. Layout, wrapping, clipping, controls and input share the same geometry on every host.", FONT_SIZE)
	count := ui.button_layout(&app.frame, font, fmt.tprintf("Click count: %d", app.clicks), FONT_SIZE, {path = "count"})
	name := ui.field_layout(&app.frame, font, string(app.name[:app.name_length]), FONT_SIZE, {path = "name"}, {width = ui.grow()})
	progress := ui.bar_layout(&app.frame, 14)
	footer := ui.paragraph_layout(&app.frame, font, "Application commands, persistence and native keyboard/IME services remain with the host.", FONT_SIZE)
	resolved, failure := ui.finish_layout(&app.frame)
	assert(failure == nil, "Showcase layout failed")
	app.resolved = resolved
	app.viewport = {width, height}
	// Hover and focus/selection appearance use this frame's finished geometry.
	hovered := ui.contains_resolved(resolved, count, {pointer.position.x, pointer.position.y})
	fill := ACCENT if hovered else PANEL
	if app.press.active {fill = BACKGROUND}
	focus := ACCENT if app.editing else rl.Color{}
	button_focus := rl.WHITE if app.focused == 1 else rl.Color{}
	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND)
	paint: ui.Paint
	ui.begin_paint(&paint, resolved)
	ui.paint_text(&paint, title, {rl.WHITE})
	ui.paint_text(&paint, description, {rl.LIGHTGRAY})
	ui.paint_button(&paint, count, {background = fill, foreground = rl.WHITE, border = ACCENT, focus = button_focus})
	ui.paint_field(&paint, name, {background = PANEL, foreground = rl.WHITE, border = ACCENT, focus = focus, selection = app.selection, selection_background = ACCENT, cursor = app.editing && int(rl.GetTime() * 2) % 2 == 0})
	ui.paint_bar(&paint, progress, {f32(app.clicks % 11) / 10, ACCENT, PANEL})
	ui.paint_text(&paint, footer, {rl.LIGHTGRAY})
	ui.end_paint(&paint)
	rl.EndDrawing()
}

edit_name :: proc(app: ^App, operation: text.Edit, inserted: string = "", extend: bool = false) {
	value, selection := text.edit(string(app.name[:app.name_length]), app.selection, operation, inserted, extend)
	if len(value) > len(app.name) {return}
	copy(app.name[:], value)
	app.name_length, app.selection = len(value), selection
}
