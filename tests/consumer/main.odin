// Copied to a separate project's src/ by scripts/check-vendored.sh.
package consumer

// -------------------------------- Imports --------------------------------

// ---------------- Project ----------------

import text "../vendor/odin_ui/text"
import input "../vendor/odin_ui/input"
import ui "../vendor/odin_ui/raylib"

// -------------------------------- Procedures --------------------------------

// ---------------- Public ----------------

main :: proc() {
	frame: ui.Layout_Builder
	ui.begin_layout(&frame, 320, 200, {direction = .vertical, alignment = {.start, .start}})
	target := ui.box_layout(&frame, {width = ui.fixed(100), height = ui.fixed(40)})
	ui.layout_action(&frame, target, {path = "continue"})
	ui.bar_layout(&frame, 12)
	resolved, failure := ui.finish_layout(&frame)
	assert(failure == nil)
	paint: ui.Paint
	ui.begin_paint(&paint, resolved)
	ui.end_paint(&paint)

	point := input.logical_position({scale = 2}, {20, 20})
	assert(ui.contains_resolved(resolved, target, {point.x, point.y}))
	assert(ui.hit_resolved(resolved, {point.x, point.y}).path == "continue")
	press: input.Press
	assert(input.button(&press, {position = point, pressed = true, down = true}, true).pressed)
	assert(input.button(&press, {position = point, released = true}, true).clicked)
	value, selection := text.edit("café", {5, 5}, .backspace)
	assert(value == "caf" && selection.cursor == 3)
}
