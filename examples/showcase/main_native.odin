#+build !js
package showcase

// -------------------------------- Imports --------------------------------

// ---------------- Vendor ----------------

import rl "vendor:raylib"

// ---------------- Odin ----------------

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:mem"
import vmem "core:mem/virtual"
import "core:os"
import "core:slice"
import "core:unicode/utf8"

// ---------------- Project ----------------

import input "odin_ui:input"

// -------------------------------- Constants --------------------------------

// ---------------- Public ----------------

TARGET_FPS :: 60

// -------------------------------- Globals --------------------------------

// ---------------- Package ----------------

@(private)
replay_tracking: mem.Tracking_Allocator

@(private)
replay_clip_depth: int

// -------------------------------- Types --------------------------------

// ---------------- File ----------------

@(private="file")
Replay_Event :: struct {
	frame: int,
	dt: f64,
	keys_down: []string,
	keys_pressed: []string,
	mouse: Replay_Mouse,
	viewport: [2]f32,
	close: bool,
	text: string,
	blur: bool,
	touches: []input.Touch,
}

@(private="file")
Replay_Mouse :: struct {x, y: f32, left, right: bool, wheel: f32}

// -------------------------------- Procedures --------------------------------

// ---------------- Public ----------------

main :: proc() {
	if #config(UI_REPLAY, false) {
		previous_context: runtime.Context = context
		defer {context = previous_context}
		// Input storage survives frame scratch resets; neither becomes application state.
		input_arena: vmem.Arena
		if vmem.arena_init_growing(&input_arena) != nil {return}
		defer vmem.arena_destroy(&input_arena)
		allocator := vmem.arena_allocator(&input_arena)
		events := make([dynamic]Replay_Event, allocator)
		// Host-only commits/focus/touch frames remain independently mutable from
		// the generated mouse/keyboard stream; both enter the same frame path.
		for filename in ([2]string{"examples/showcase/host-events.json", "examples/showcase/events.json"}) {
			data, error := os.read_entire_file(filename, allocator)
			if error != nil {continue}
			if len(data) > 4096 {return}
			parsed: []Replay_Event
			if json.unmarshal(data, &parsed, allocator = allocator) != nil || len(parsed) > 256 {return}
			append(&events, ..parsed)
		}
		if len(events) > 256 {return}
		// Reject malformed events before any conversion to library input.
		for event in events {
			if !utf8.valid_string(event.text) || !replay_finite(event.dt) || event.dt < 0 || event.dt > 10 {return}
			for dimension in event.viewport {if !replay_finite(dimension) || dimension < 0 || dimension > 16384 {return}}
			if !replay_finite(event.mouse.x) || !replay_finite(event.mouse.y) {return}
			if len(event.touches) > 8 {return}
			for touch, index in event.touches {
				if touch.id < 0 || !replay_finite(touch.position.x) || !replay_finite(touch.position.y) {return}
				for previous in event.touches[:index] {if previous.id == touch.id {return}}
			}
		}
		// CPU font loading and atlas construction preserve the native font metrics.
		// The texture ID marks valid metrics; all drawing is observed below, with no GPU.
		font := rl.Font{baseSize = FONT_RASTER_SIZE, glyphPadding = 4, texture = {id = 1}}
		codepoints: [GLYPH_COUNT]rune
		for &codepoint, index in codepoints {codepoint = rune(index + FIRST_CODEPOINT)}
		font.glyphs = rl.LoadFontData(raw_data(FONT_DATA), i32(len(FONT_DATA)), FONT_RASTER_SIZE, raw_data(codepoints[:]), GLYPH_COUNT, .DEFAULT, &font.glyphCount)
		if font.glyphs == nil {return}
		defer rl.UnloadFontData(font.glyphs, font.glyphCount)
		atlas := rl.GenImageFontAtlas(font.glyphs, &font.recs, font.glyphCount, FONT_RASTER_SIZE, font.glyphPadding, 0)
		defer rl.UnloadImage(atlas)
		defer rl.MemFree(font.recs)
		if font.recs == nil {return}
		app := initialize(font)
		mem.tracking_allocator_init(&replay_tracking, context.temp_allocator)
		defer mem.tracking_allocator_destroy(&replay_tracking)
		context.temp_allocator = mem.tracking_allocator(&replay_tracking)
		processed := 0
		time: f64
		for event in events {
			if event.close {break}
			time += event.dt
			mouse := input.Pointer{position = {event.mouse.x, event.mouse.y}, down = event.mouse.left,
				pressed = event.mouse.left && !app.pointer.down, released = !event.mouse.left && app.pointer.down}
			value := Frame_Input{pointer = input.pointer(app.pointer, mouse, event.touches, !event.blur), focused = !event.blur, text = event.text, time = time}
			value.shift = slice.contains(event.keys_down, "LEFT_SHIFT") || slice.contains(event.keys_down, "RIGHT_SHIFT")
			value.command = slice.contains(event.keys_down, "LEFT_CONTROL") || slice.contains(event.keys_down, "RIGHT_CONTROL") || slice.contains(event.keys_down, "LEFT_SUPER") || slice.contains(event.keys_down, "RIGHT_SUPER")
			for binding in ([]struct {name: string, key: Key}{
				{"TAB", .tab}, {"ENTER", .enter}, {"SPACE", .space}, {"A", .a}, {"BACKSPACE", .backspace},
				{"DELETE", .delete}, {"LEFT", .left}, {"RIGHT", .right}, {"HOME", .home}, {"END", .end},
			}) {
				if slice.contains(event.keys_pressed, binding.name) {value.pressed += {binding.key}}
			}
			frame(&app, event.viewport[0], event.viewport[1], &value)
			processed += 1
			assert(!app.press.active || !event.blur)
		}
		fmt.printf("replay: frames=%d clicks=%d focus=%d name=%q\n", processed, app.clicks, app.focused, string(app.name[:app.name_length]))
		free_all(context.temp_allocator)
	} else {
		app := initialize()
		defer rl.CloseWindow()
		defer rl.UnloadFont(app.font)
		rl.SetTargetFPS(TARGET_FPS)
		for !rl.WindowShouldClose() {
			frame(&app, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
		}
	}
}

when #config(UI_REPLAY, false) {
// Interposition observes every draw without a fixed-size recorder or graphics context.
// Linux uses --wrap; macOS interposes the bundled shared raylib.
@(export, link_name = "__wrap_BeginScissorMode" when ODIN_OS == .Linux else "BeginScissorMode")
replay_begin_clip :: proc "c" (x, y, width, height: i32) {
	context = runtime.default_context()
	assert(replay_clip_depth == 0 && width >= 0 && height >= 0)
	replay_clip_depth += 1
}

@(export, link_name = "__wrap_EndScissorMode" when ODIN_OS == .Linux else "EndScissorMode")
replay_end_clip :: proc "c" () {
	context = runtime.default_context()
	assert(replay_clip_depth == 1)
	replay_clip_depth -= 1
}

@(export, link_name = "__wrap_DrawRectangleRoundedLinesEx" when ODIN_OS == .Linux else "DrawRectangleRoundedLinesEx")
replay_border :: proc "c" (rect: rl.Rectangle, roundness: f32, segments: i32, width: f32, color: rl.Color) {
	context = runtime.default_context()
	replay_rounded(rect, roundness, segments, color)
	assert(replay_finite(width) && width >= 0)
}

@(export, link_name = "__wrap_DrawRectangleRounded" when ODIN_OS == .Linux else "DrawRectangleRounded")
replay_rounded :: proc "c" (rect: rl.Rectangle, roundness: f32, segments: i32, color: rl.Color) {
	context = runtime.default_context()
	replay_rectangle(rect, color)
	assert(replay_finite(roundness) && roundness >= 0 && roundness <= 1 && segments >= 1)
}

@(export, link_name = "__wrap_DrawRectangleRec" when ODIN_OS == .Linux else "DrawRectangleRec")
replay_rectangle :: proc "c" (rect: rl.Rectangle, color: rl.Color) {
	context = runtime.default_context()
	assert(replay_clip_depth == 1)
	assert(replay_finite(rect.x) && replay_finite(rect.y) && replay_finite(rect.width) && replay_finite(rect.height))
}

@(export, link_name = "__wrap_DrawTextCodepoints" when ODIN_OS == .Linux else "DrawTextCodepoints")
replay_text :: proc "c" (font: rl.Font, points: ^rune, count: i32, origin: rl.Vector2, size, spacing: f32, color: rl.Color) {
	context = runtime.default_context()
	assert(replay_clip_depth == 1 && count >= 0)
	assert(replay_finite(origin.x) && replay_finite(origin.y) && replay_finite(size) && replay_finite(spacing))
}
}

// ---------------- File ----------------

@(private="file")
replay_finite :: proc(value: $T) -> bool {return !math.is_nan(value) && !math.is_inf(value)}
