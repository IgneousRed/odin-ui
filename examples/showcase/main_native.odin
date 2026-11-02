#+build !js
package main

import rl "vendor:raylib"

TARGET_FPS :: 60

main :: proc() {
    app := initialize()
    defer rl.CloseWindow()
    defer rl.UnloadFont(app.font)
    rl.SetTargetFPS(TARGET_FPS)
    for !rl.WindowShouldClose() {
        frame(&app, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
    }
}
