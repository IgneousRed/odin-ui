package main

import ui "odin_ui:raylib"
import input "odin_ui:input"
import text "odin_ui:text"
import "core:fmt"
import rl "vendor:raylib"

FONT_SIZE :: f32(22)
BACKGROUND :: rl.Color{26, 29, 36, 255}
PANEL :: rl.Color{45, 51, 64, 255}
ACCENT :: rl.Color{75, 128, 220, 255}
FONT_DATA :: #load("assets/AtkinsonHyperlegibleNext-SemiBold.ttf", []u8)

App :: struct {
    frame: ui.UI,
    pointer: input.Pointer,
    press: input.Press,
    clicks: int,
    name: [256]u8,
    name_length: int,
    selection: text.Selection,
    editing: bool,
}

app: App
app_font: rl.Font

initialize :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(800, 600, "Odin UI")
    codepoints: [224]rune
    for &codepoint, index in codepoints {codepoint = rune(index + 32)}
    app_font = rl.LoadFontFromMemory(".ttf", raw_data(FONT_DATA), i32(len(FONT_DATA)), 48, raw_data(codepoints[:]), i32(len(codepoints)))
    rl.SetTextureFilter(app_font.texture, .BILINEAR)
    copy(app.name[:], "Edit me: café")
    app.name_length = len("Edit me: café")
    app.selection = {app.name_length, app.name_length}
}

frame :: proc(width, height: f32) {
    pointer := ui.pointer(app.pointer)
    if app.frame.count > 0 && app.frame.viewport.width == width && app.frame.viewport.height == height {
        trigger := ui.hit(&app.frame, {pointer.position.x, pointer.position.y})
        event := input.button(&app.press, pointer, trigger.path == "count")
        if event.clicked {app.clicks += 1}
        if pointer.pressed {app.editing = trigger.path == "name"}
    } else {app.press = {}}
    app.pointer = pointer
    if app.editing {
        if rl.IsKeyPressed(.BACKSPACE) {edit_name(.backspace)}
        if rl.IsKeyPressed(.LEFT) {edit_name(.left)}
        if rl.IsKeyPressed(.RIGHT) {edit_name(.right)}
        inserted := ""
        for code := rl.GetCharPressed(); code != 0; code = rl.GetCharPressed() {inserted = fmt.tprintf("%s%c", inserted, code)}
        if inserted != "" {edit_name(.insert, inserted)}
    }
    free_all(context.temp_allocator)
    ui.begin(&app.frame, width, height, {direction = .vertical, padding = {20, 20, 20, 20}, gap = 12, alignment = {.stretch, .start}})
    font := app_font
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

edit_name :: proc(operation: text.Edit, inserted: string = "") {
    value, selection := text.edit(string(app.name[:app.name_length]), app.selection, operation, inserted)
    if len(value) > len(app.name) {return}
    copy(app.name[:], value)
    app.name_length, app.selection = len(value), selection
}
