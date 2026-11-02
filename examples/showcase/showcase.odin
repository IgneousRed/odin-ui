package main

import ui "odin_ui:raylib"
import input "odin_ui:input"
import text "odin_ui:text"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

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

// Keep this instance in place after building a frame, which borrows its node array.
App :: struct {
    frame: ui.UI,
    nodes: [NODE_CAPACITY]ui.Node,
    font: rl.Font,
    pointer: input.Pointer,
    press: input.Press,
    clicks: int,
    name: [NAME_CAPACITY]u8,
    name_length: int,
    selection: text.Selection,
    editing: bool,
}

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
    if app.frame.count > 0 && app.frame.viewport.width == width && app.frame.viewport.height == height {
        trigger := ui.hit(&app.frame, {pointer.position.x, pointer.position.y})
        event := input.button(&app.press, pointer, trigger.path == "count")
        if event.clicked {app.clicks += 1}
        if pointer.pressed {app.editing = trigger.path == "name"}
    } else {app.press = {}}
    app.pointer = pointer
    if app.editing {
        if rl.IsKeyPressed(.BACKSPACE) {edit_name(app, .backspace)}
        if rl.IsKeyPressed(.LEFT) {edit_name(app, .left)}
        if rl.IsKeyPressed(.RIGHT) {edit_name(app, .right)}
        inserted := strings.builder_make(allocator = context.temp_allocator)
        for code := rl.GetCharPressed(); code != 0; code = rl.GetCharPressed() {strings.write_rune(&inserted, code)}
        if value := strings.to_string(inserted); value != "" {edit_name(app, .insert, value)}
    }
    free_all(context.temp_allocator)
    padding := CONTENT_PADDING
    ui.begin(&app.frame, width, height, {direction = .vertical, padding = {padding, padding, padding, padding}, gap = CONTENT_GAP, alignment = {.stretch, .start}}, storage = app.nodes[:])
    font := app.font
    ui.paragraph(&app.frame, font, "Shared Odin UI", FONT_SIZE * 1.5, rl.WHITE)
    ui.paragraph(&app.frame, font, "Resize this window. Layout, wrapping, clipping, controls and input share the same geometry on every host.", FONT_SIZE, rl.LIGHTGRAY)
    ui.button(&app.frame, font, fmt.tprintf("Click count: %d", app.clicks), FONT_SIZE, ACCENT, PANEL, {path = "count"}, {pressed = app.press.active})
    ui.field(&app.frame, font, string(app.name[:app.name_length]), FONT_SIZE, PANEL, ACCENT, {path = "name"},
             {width = ui.grow(), cursor = app.editing, selection = app.selection,
              selection_background = ACCENT})
    ui.bar(&app.frame, f32(app.clicks % 11) / 10, 14, ACCENT, PANEL)
    ui.paragraph(&app.frame, font, "Application commands, persistence and native keyboard/IME services remain with the host.", FONT_SIZE, rl.LIGHTGRAY)
    assert(ui.finish(&app.frame) == nil, "Showcase layout failed")
    rl.BeginDrawing()
    rl.ClearBackground(BACKGROUND)
    ui.draw(&app.frame)
    rl.EndDrawing()
}

edit_name :: proc(app: ^App, operation: text.Edit, inserted: string = "") {
    value, selection := text.edit(string(app.name[:app.name_length]), app.selection, operation, inserted)
    if len(value) > len(app.name) {return}
    copy(app.name[:], value)
    app.name_length, app.selection = len(value), selection
}
