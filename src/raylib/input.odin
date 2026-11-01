package raylib_ui

import input "../input"
import rl "vendor:raylib"

// Input collection is optional: custom hosts can supply the same portable Pointer directly.
pointer :: proc(previous: input.Pointer, scale: f32 = 1) -> input.Pointer {
    if !rl.IsWindowFocused() {return {id = previous.id, position = previous.position, cancelled = previous.down}}
    ratio := scale if scale > 0 else 1
    count := rl.GetTouchPointCount()
    if count > 0 {
        index := i32(0)
        matched := false
        for candidate in 0 ..< count {
            if int(rl.GetTouchPointId(candidate)) == previous.id {index = candidate; matched = true; break}
        }
        if previous.down && !matched {return {id = previous.id, position = previous.position, cancelled = true}}
        id := int(rl.GetTouchPointId(index))
        position := rl.GetTouchPosition(index)
        return {position = {position.x / ratio, position.y / ratio}, id = id,
                pressed = !previous.down || previous.id != id, down = true}
    }
    if previous.down && previous.id >= 0 {return {id = previous.id, position = previous.position, released = true}}
    position := rl.GetMousePosition()
    return {position = {position.x / ratio, position.y / ratio}, id = -1,
            pressed = rl.IsMouseButtonPressed(.LEFT), down = rl.IsMouseButtonDown(.LEFT),
            released = rl.IsMouseButtonReleased(.LEFT)}
}

node_trigger :: proc(node: ^Node) -> Trigger {
    return node.trigger
}

hit :: proc(ui: ^UI, point: rl.Vector2) -> Trigger {
    for index := ui.count - 1; index >= 0; index -= 1 {
        if contains(ui, index, point) {
            trigger := node_trigger(&ui.nodes[index])
            if trigger.path != "" || trigger.data != nil {return trigger}
        }
    }
    return {}
}
