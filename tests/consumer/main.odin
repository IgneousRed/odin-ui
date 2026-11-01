// Copied to a separate project's src/ by scripts/check-vendored.sh.
package main

import layout "../vendor/odin_ui/layout"
import text "../vendor/odin_ui/text"
import input "../vendor/odin_ui/input"
import ui "../vendor/odin_ui/raylib"
import rl "vendor:raylib"

main :: proc() {
    frame: ui.UI
    ui.begin(&frame, 320, 200, {direction = .vertical, alignment = {.start, .start}})
    target := ui.layout_leaf(&frame, {width = ui.fixed(100), height = ui.fixed(40)})
    ui.action(&frame, target, {path = "continue"})
    ui.bar(&frame, 0.5, 12, rl.BLUE, rl.GRAY)
    assert(ui.finish(&frame) == nil)

    point := input.logical_position({scale = 2}, {20, 20})
    assert(layout.contains(&frame, target, point))
    assert(ui.hit(&frame, {point.x, point.y}).path == "continue")
    press: input.Press
    assert(input.button(&press, {position = point, pressed = true, down = true}, true).pressed)
    assert(input.button(&press, {position = point, released = true}, true).clicked)
    value, selection := text.edit("café", {5, 5}, .backspace)
    assert(value == "caf" && selection.cursor == 3)
}
