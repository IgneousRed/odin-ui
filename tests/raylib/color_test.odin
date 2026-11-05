package tests

import ui "../../src/raylib"
import "core:testing"
import rl "vendor:raylib"

@(test)
hsl_hues_wrap_in_both_directions :: proc(t: ^testing.T) {
    primaries := [6]rl.Color{{255, 0, 0, 255}, {255, 255, 0, 255}, {0, 255, 0, 255},
                            {0, 255, 255, 255}, {0, 0, 255, 255}, {255, 0, 255, 255}}
    for expected, sector in primaries {
        for turns in -2 ..= 2 {
            hue := f32(sector * 60 + turns * 360)
            testing.expect_value(t, ui.hsl(hue, 1, 0.5), expected)
            testing.expect_value(t, ui.hsl_color({hue, 1, 0.5}), expected)
        }
    }
}

@(test)
hsl_blends_preserve_and_interpolate_opacity :: proc(t: ^testing.T) {
    start := rl.Color{255, 0, 0, 32}
    end := rl.Color{0, 0, 255, 224}
    testing.expect_value(t, ui.hsl_blend(start, end, 0), start)
    testing.expect_value(t, ui.hsl_blend(start, end, 1), end)
    testing.expect_value(t, ui.hsl_blend(start, end, 0.5), {255, 0, 255, 128})
    testing.expect_value(t, ui.hsl_blend({0, 0, 0, 0}, {0, 0, 0, 0}, 0.5), {})
}
