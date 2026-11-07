package text_tests

// -------------------------------- Imports --------------------------------

// ---------------- Odin ----------------

import "core:testing"

// ---------------- Project ----------------

import layout "../../src/layout"
import text "../../src/text"

// -------------------------------- Procedures --------------------------------

// ---------------- Public ----------------

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

@(test)
wrapping_normalizes_words_and_preserves_empty_paragraphs :: proc(t: ^testing.T) {
    cases := []struct {value: string, width: f32, expected: []string}{
        {"  a\t b \n\nø\u2003c\n", 100, {"a b", "", "ø c", ""}},
        {" a\tbcdef  g\n h  ", 30, {"a", "bcd", "ef", "g", "h"}},
        {"é🙂ø\u2003z", 20, {"é🙂", "ø", "z"}},
        {" a  b ", 0, {"a", "b"}},
        {" \n\t\n", 10, {"", "", ""}},
        {"", 10, {""}},
    }
    for sample in cases {
        lines := text.lines(sample.value, sample.width, 10, monospace)
        if !testing.expect_value(t, len(lines), len(sample.expected)) {continue}
        for expected, index in sample.expected {
            testing.expect_value(t, lines[index], expected)
        }
    }
}

@(test)
truncation_measures_the_actual_suffix_candidate :: proc(t: ^testing.T) {
    testing.expect_value(t, text.fit("Axxxxx", 10, 15, "V", kerning), "AV")
    testing.expect_value(t, text.fit("é🙂abc", 10, 35, "…", monospace), "é🙂…")
}

@(test)
truncation_finds_the_longest_fitting_prefix_without_monotonic_widths :: proc(t: ^testing.T) {
    for width in ([2]f32{15, 25}) {
        testing.expect_value(t, text.fit("é🙂abc", 10, width, "…", contracting_measure), "é🙂…")
        testing.expect_value(t, text.fit("é🙂", 10, width, "…", contracting_measure), "é🙂…")
    }
    testing.expect_value(t, text.fit("é🙂abc", 10, 5, "…", contracting_measure), "")
}

@(test)
wrapping_measures_whole_runs_when_splitting_words :: proc(t: ^testing.T) {
    lines := text.lines(" AV  AVAV\tX ", 25, 10, kerning)
    testing.expect_value(t, len(lines), 4)
    for expected, index in ([4]string{"AV", "AVA", "V", "X"}) {
        testing.expect_value(t, lines[index], expected)
    }
}

// A measurement callback may depend on whole runs (for example, kerning).
kerning :: proc(value: string, size: f32, data: rawptr) -> layout.Vec2 {
    width := monospace(value, size, data).x
    for index in 1 ..< len(value) {
        if value[index - 1] == 'A' && value[index] == 'V' {width -= size / 2}
    }
    return {width, size}
}

monospace :: proc(value: string, size: f32, data: rawptr) -> layout.Vec2 {
    count := 0
    for _ in value {count += 1}
    return {f32(count) * size, size}
}

// Shaping can make a longer candidate narrower, even than the suffix alone.
contracting_measure :: proc(value: string, size: f32, data: rawptr) -> layout.Vec2 {
    switch value {
    case "…": return {20, size}
    case "é🙂…": return {10, size}
    case: return {100, size}
    }
}
