package text

import layout "../layout"
import "core:strings"

Measure :: #type proc(value: string, pixel_size: f32, data: rawptr) -> layout.Vec2

// Byte offsets are always brought back to a complete UTF-8 codepoint.
boundary :: proc(value: string, desired: int) -> int {
    position := clamp(desired, 0, len(value))
    for position > 0 && position < len(value) && value[position] & 0xc0 == 0x80 {
        position -= 1
    }
    return position
}

previous :: proc(value: string, position: int) -> int {
    return boundary(value, max(0, boundary(value, position) - 1))
}

next :: proc(value: string, position: int) -> int {
    offset := boundary(value, position)
    if offset < len(value) {offset += 1}
    for offset < len(value) && value[offset] & 0xc0 == 0x80 {offset += 1}
    return offset
}

// Uses the same lines for measurement and drawing. An over-wide glyph stays whole.
lines :: proc(value: string, width, pixel_size: f32, measure: Measure, data: rawptr = nil) -> []string {
    result := make([dynamic]string, context.temp_allocator)
    for &paragraph in strings.split(value, "\n", context.temp_allocator) {
        line := ""
        for word in strings.fields_iterator(&paragraph) {
            candidate := word if line == "" else strings.concatenate({line, " ", word}, context.temp_allocator)
            if line != "" && measure(candidate, pixel_size, data).x > width {
                append(&result, line)
                line = ""
            }
            if measure(word, pixel_size, data).x <= width {
                line = word if line == "" else candidate
                continue
            }
            start, end := 0, 0
            for end < len(word) {
                following := next(word, end)
                if end > start && measure(word[start:following], pixel_size, data).x > width {
                    append(&result, word[start:end])
                    start = end
                }
                end = following
            }
            remainder := word[start:]
            line = remainder if line == "" else strings.concatenate({line, " ", remainder}, context.temp_allocator)
        }
        append(&result, line)
    }
    return result[:]
}

fit :: proc(value: string, pixel_size, width: f32, suffix: string, measure: Measure, data: rawptr = nil) -> string {
    if measure(value, pixel_size, data).x <= width {return value}
    if measure(suffix, pixel_size, data).x > width {return ""}
    end := 0
    for end < len(value) {
        following := next(value, end)
        candidate := strings.concatenate({value[:following], suffix}, context.temp_allocator)
        if measure(candidate, pixel_size, data).x > width {break}
        end = following
    }
    return strings.concatenate({value[:end], suffix}, context.temp_allocator)
}

Selection :: struct {anchor, cursor: int}
Edit :: enum {insert, backspace, delete_forward, left, right, home, end, select_all}

// Returns frame-allocated text; the application decides whether and how to persist it.
edit :: proc(value: string, initial: Selection, operation: Edit, inserted: string = "", extend: bool = false) -> (string, Selection) {
    selection := Selection{boundary(value, initial.anchor), boundary(value, initial.cursor)}
    first, last := min(selection.anchor, selection.cursor), max(selection.anchor, selection.cursor)
    switch operation {
    case .select_all:
        return value, {0, len(value)}
    case .home, .end, .left, .right:
        #partial switch operation {
        case .home: selection.cursor = 0
        case .end: selection.cursor = len(value)
        case .left: selection.cursor = first if first != last && !extend else previous(value, selection.cursor)
        case .right: selection.cursor = last if first != last && !extend else next(value, selection.cursor)
        case:
        }
        if !extend {selection.anchor = selection.cursor}
        return value, selection
    case .backspace:
        if first == last {first = previous(value, first)}
    case .delete_forward:
        if first == last {last = next(value, last)}
    case .insert:
    }
    replacement := inserted if operation == .insert else ""
    changed := strings.concatenate({value[:first], replacement, value[last:]}, context.temp_allocator)
    cursor := first + len(replacement)
    return changed, {cursor, cursor}
}
