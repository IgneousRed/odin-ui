package text

import layout "../layout"
import "core:strings"
import "core:mem"

Measure :: #type proc(value: string, pixel_size: f32, data: rawptr) -> layout.Vec2

// Inputs are valid UTF-8; byte offsets are brought back to a complete codepoint.
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

// Inputs are valid UTF-8. Paragraph whitespace is normalized to single spaces;
// explicit newlines and empty paragraphs survive. An over-wide codepoint stays whole.
// Result lines share one buffer: reclaim allocations together with their frame/arena.
lines :: proc(value: string, width, pixel_size: f32, measure: Measure, data: rawptr = nil, allocator: mem.Allocator = context.temp_allocator) -> []string {
    result := make([dynamic]string, allocator)
    buffer := make([]u8, len(value), allocator)
    used, paragraph_start := 0, 0
    for paragraph_end in 0 ..= len(value) {
        if paragraph_end < len(value) && value[paragraph_end] != '\n' {continue}
        paragraph := value[paragraph_start:paragraph_end]
        paragraph_start = paragraph_end + 1
        line_start := used
        for word in strings.fields_iterator(&paragraph) {
            if used > line_start {buffer[used] = ' '; used += 1}
            word_start := used
            used += copy(buffer[used:], word)
            written := string(buffer[:used])
            if word_start > line_start && measure(written[line_start:], pixel_size, data).x > width {
                append(&result, written[line_start:word_start - 1])
                line_start = word_start
            }
            if measure(word, pixel_size, data).x <= width {continue}
            end := word_start
            for end < used {
                following := next(written, end)
                if end > line_start && measure(written[line_start:following], pixel_size, data).x > width {
                    append(&result, written[line_start:end])
                    line_start = end
                }
                end = following
            }
        }
        append(&result, string(buffer[line_start:used]))
    }
    return result[:]
}

fit :: proc(value: string, pixel_size, width: f32, suffix: string, measure: Measure, data: rawptr = nil, allocator: mem.Allocator = context.temp_allocator) -> string {
    if measure(value, pixel_size, data).x <= width {return value}
    if measure(suffix, pixel_size, data).x > width {return ""}
    // Reuse one candidate buffer without assuming character advances are additive.
    buffer := make([]u8, len(value) + len(suffix), allocator)
    end := 0
    for end < len(value) {
        following := next(value, end)
        copy(buffer[end:following], value[end:following])
        copy(buffer[following:], suffix)
        if measure(string(buffer[:following + len(suffix)]), pixel_size, data).x > width {break}
        end = following
    }
    copy(buffer[end:], suffix)
    return string(buffer[:end + len(suffix)])
}

Selection :: struct {anchor, cursor: int}
Edit :: enum {insert, backspace, delete_forward, left, right, home, end, select_all}

// Returns frame-allocated text; the application decides whether and how to persist it.
edit :: proc(value: string, initial: Selection, operation: Edit, inserted: string = "", extend: bool = false, allocator: mem.Allocator = context.temp_allocator) -> (string, Selection) {
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
    changed := strings.concatenate({value[:first], replacement, value[last:]}, allocator)
    cursor := first + len(replacement)
    return changed, {cursor, cursor}
}
