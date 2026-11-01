package tests

import text "../../src/text"
import layout "../../src/layout"
import "core:testing"

monospace :: proc(value: string, size: f32, data: rawptr) -> layout.Vec2 {
    count := 0
    for _ in value {count += 1}
    return {f32(count) * size, size}
}

@(test)
wrapping_and_truncation_preserve_codepoints :: proc(t: ^testing.T) {
    lines := text.lines("ééééé\n\nx", 20, 10, monospace)
    testing.expect_value(t, len(lines), 5)
    testing.expect_value(t, lines[0], "éé")
    testing.expect_value(t, lines[2], "é")
    testing.expect_value(t, lines[3], "")
    testing.expect_value(t, text.fit("abcdef", 10, 50, "...", monospace), "ab...")
    testing.expect_value(t, text.fit("abcdef", 10, 20, "...", monospace), "")
    lines = text.lines("é", 0, 10, monospace)
    testing.expect_value(t, lines[0], "é")
}

@(test)
editing_uses_utf8_selection_boundaries :: proc(t: ^testing.T) {
    value, selection := text.edit("aé🙂z", {1, 7}, .insert, "ø")
    testing.expect_value(t, value, "aøz")
    testing.expect_value(t, selection, {3, 3})
    value, selection = text.edit(value, selection, .backspace)
    testing.expect_value(t, value, "az")
    value, selection = text.edit("a🙂z", {5, 5}, .left)
    testing.expect_value(t, selection, {1, 1})
    value, selection = text.edit(value, selection, .delete_forward)
    testing.expect_value(t, value, "az")
    value, selection = text.edit(value, selection, .select_all)
    value, selection = text.edit(value, selection, .insert, "")
    testing.expect_value(t, value, "")
    testing.expect_value(t, selection, {0, 0})
}
