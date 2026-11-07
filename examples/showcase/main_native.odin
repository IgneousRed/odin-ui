#+build !js
package showcase

// -------------------------------- Imports --------------------------------

// ---------------- Vendor ----------------

import rl "vendor:raylib"

// -------------------------------- Constants --------------------------------

// ---------------- Public ----------------

TARGET_FPS :: 60

// -------------------------------- Procedures --------------------------------

// ---------------- Public ----------------

main :: proc() {
    app := initialize()
    defer rl.CloseWindow()
    defer rl.UnloadFont(app.font)
    rl.SetTargetFPS(TARGET_FPS)
    for !rl.WindowShouldClose() {
        frame(&app, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
    }
}
