#+build js
package showcase

// -------------------------------- Imports --------------------------------

// ---------------- Vendor ----------------

import rl "vendor:raylib"

// ---------------- Odin ----------------

import "base:runtime"
import "core:mem"

// -------------------------------- Constants --------------------------------

// ---------------- Public ----------------

WEB_SCRATCH_CAPACITY :: 8 * mem.Megabyte

// -------------------------------- Globals --------------------------------

// ---------------- Public ----------------

web_app: App
web_scratch: [WEB_SCRATCH_CAPACITY]u8
web_arena: mem.Arena
web_context: runtime.Context

// -------------------------------- Procedures --------------------------------

// ---------------- Public ----------------

main :: proc() {}

@(export)
ui_start :: proc "c" () {
    context = runtime.default_context()
    mem.arena_init(&web_arena, web_scratch[:])
    context.temp_allocator = mem.arena_allocator(&web_arena)
    context.allocator = context.temp_allocator
    web_context = context
    web_app = initialize()
}

// The browser owns scheduling; invoke this from requestAnimationFrame.
@(export)
ui_frame :: proc "c" (width, height: i32) {
    context = web_context
    if rl.GetScreenWidth() != width || rl.GetScreenHeight() != height {rl.SetWindowSize(width, height)}
    frame(&web_app, f32(width), f32(height))
}
