#+build !js
package main

import rl "vendor:raylib"

main :: proc() {
    initialize()
    defer rl.CloseWindow()
    defer rl.UnloadFont(app_font)
    rl.SetTargetFPS(60)
    for !rl.WindowShouldClose() {
        frame(f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
    }
}
