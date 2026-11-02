package raylib_ui

import input "../input"
import layout "../layout"
import rl "vendor:raylib"

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
