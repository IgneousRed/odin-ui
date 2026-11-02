package layout

import "core:math"
import "core:mem"

NODE_CAPACITY :: #config(UI_NODE_CAPACITY, 1024)
DEPTH_CAPACITY :: #config(UI_DEPTH_CAPACITY, 32)
INVALID_INDEX :: -1
#assert(NODE_CAPACITY > 0 && DEPTH_CAPACITY > 0)

Vec2 :: struct {x, y: f32}
Rect :: struct {x, y, width, height: f32}
Direction :: enum u8 {horizontal, vertical}
Align :: enum u8 {centre, start, end, stretch}
Alignment :: struct {horizontal, vertical: Align}
Fixed :: struct {value: f32}
Grow :: struct {}
// nil fits content; zero initialization is the ordinary layout.
Size :: union {Fixed, Grow}
Padding :: struct {left, top, right, bottom: f32}
Trigger :: struct {path: string, data: rawptr}
Style :: struct($Color: typeid) {
    direction: Direction,
    width, height: Size,
    padding: Padding,
    gap: f32,
    alignment: Alignment,
    background: Color,
    has_background: bool,
    radius: f32,
    clip_content: bool,
    scroll: bool,
    scroll_offset: f32,
    scroll_color: Color,
}
Unbalanced :: struct {}
Invalid_Dimensions :: struct {}
Node_Capacity_Exceeded :: struct {}
Depth_Capacity_Exceeded :: struct {}
Failure :: union {Invalid_Dimensions, Node_Capacity_Exceeded, Depth_Capacity_Exceeded, Unbalanced}
Node :: struct($Content: typeid, $Color: typeid) {
    parent, first_child, last_child, next_sibling: int,
    style: Style(Color),
    intrinsic: Vec2,
    measured_width, measured_height: f32,
    rect, clip: Rect,
    max_scroll: f32,
    content: Content,
    trigger: Trigger,
}
Frame :: struct($Content: typeid, $Color: typeid) {
    nodes: []Node(Content, Color),
    count: int,
    stack: [DEPTH_CAPACITY]int,
    depth: int,
    failure: Failure,
    viewport: Rect,
}

fixed :: proc(value: f32) -> Size {return Fixed{value}}
grow :: proc() -> Size {return Grow{}}

begin :: proc(ui: ^Frame($Content, $Color), width, height: f32, style: Style(Color), allocator: mem.Allocator = context.temp_allocator) {
    ui^ = {}
    ui.viewport = {
        width  = width,
        height = height,
    }
    if !number_valid(width) || !number_valid(height) || !style_valid(style) {
        ui.failure = Invalid_Dimensions{}
        return
    }
    ui.nodes = make([]Node(Content, Color), NODE_CAPACITY, allocator)
    ui.nodes[0] = {
        first_child  = INVALID_INDEX,
        last_child   = INVALID_INDEX,
        next_sibling = INVALID_INDEX,
        style        = style,
    }
    ui.count = 1
    ui.stack[0] = 0
    ui.depth = 1
}

open :: proc(frame: ^Frame($Content, $Color), style: Style(Color)) -> int {
    if frame.depth == DEPTH_CAPACITY {
        fail(frame, Depth_Capacity_Exceeded{})
        return INVALID_INDEX
    }
    index := leaf(frame, style)
    if index < 0 {return index}
    frame.stack[frame.depth] = index
    frame.depth += 1
    return index
}

close :: proc(ui: ^Frame($Content, $Color)) {
    if ui.depth <= 1 {
        fail(ui, Unbalanced{})
        return
    }
    ui.depth -= 1
}

@(private)
number_valid :: proc(value: f32) -> bool {
    return value >= 0 && !math.is_inf(value)
}

@(private)
rect_valid :: proc(rect: Rect) -> bool {
    return !math.is_nan(rect.x) && !math.is_inf(rect.x) &&
        !math.is_nan(rect.y) && !math.is_inf(rect.y) &&
        number_valid(rect.width) && number_valid(rect.height) &&
        !math.is_inf(rect.x + rect.width) && !math.is_inf(rect.y + rect.height)
}

@(private)
sizing_valid :: proc(sizing: Size) -> bool {
    switch size in sizing {
    case nil, Grow:
        return true
    case Fixed:
        return number_valid(size.value)
    }
    return false
}

@(private)
padding_valid :: proc(padding: Padding) -> bool {
    return(
        number_valid(padding.left) &&
        number_valid(padding.top) &&
        number_valid(padding.right) &&
        number_valid(padding.bottom) \
    )
}

@(private)
style_valid :: proc(style: Style($Color)) -> bool {
    return sizing_valid(style.width) && sizing_valid(style.height) &&
        padding_valid(style.padding) && number_valid(style.gap) &&
        number_valid(style.radius) && number_valid(style.scroll_offset)
}

@(private)
fail :: proc(frame: ^Frame($Content, $Color), failure: Failure) {
    if frame.failure == nil do frame.failure = failure
}

leaf :: proc(frame: ^Frame($Content, $Color), style: Style(Color), intrinsic: Vec2 = {}) -> int {
    if frame.failure != nil do return INVALID_INDEX
    if !style_valid(style) || !number_valid(intrinsic.x) || !number_valid(intrinsic.y) {
        fail(frame, Invalid_Dimensions{})
        return INVALID_INDEX
    }
    if frame.count == NODE_CAPACITY {
        fail(frame, Node_Capacity_Exceeded{})
        return INVALID_INDEX
    }
    if frame.depth == 0 {
        fail(frame, Unbalanced{})
        return INVALID_INDEX
    }
    parent := frame.stack[frame.depth - 1]
    index := frame.count
    frame.count += 1
    frame.nodes[index] = {
        first_child  = INVALID_INDEX,
        last_child   = INVALID_INDEX,
        next_sibling = INVALID_INDEX,
        style        = style,
        parent       = parent,
        intrinsic    = intrinsic,
    }
    if frame.nodes[parent].first_child < 0 {
        frame.nodes[parent].first_child = index
    } else {
        frame.nodes[frame.nodes[parent].last_child].next_sibling = index
    }
    frame.nodes[parent].last_child = index
    return index
}

@(private)
size :: proc(sizing: Size, content: f32) -> f32 {
    switch size in sizing {
    case nil, Grow:
        return content
    case Fixed:
        return size.value
    }
    return 0
}

@(private)
measure :: proc(frame: ^Frame($Content, $Color), index: int) {
    node := &frame.nodes[index]
    style := node.style
    if node.first_child < 0 {
        node.measured_width = size(style.width, node.intrinsic.x + style.padding.left + style.padding.right)
        node.measured_height = size(style.height, node.intrinsic.y + style.padding.top + style.padding.bottom)
        return
    }
    horizontal := style.direction == .horizontal
    main: f32
    cross: f32
    children := 0
    child := node.first_child
    for child >= 0 {
        measure(frame, child)
        measured := &frame.nodes[child]
        main += measured.measured_width if horizontal else measured.measured_height
        cross = max(cross, measured.measured_height if horizontal else measured.measured_width)
        children += 1
        child = measured.next_sibling
    }
    if children > 1 do main += style.gap * f32(children - 1)
    content_width := main if horizontal else cross
    content_height := cross if horizontal else main
    node.measured_width = size(style.width, content_width + style.padding.left + style.padding.right)
    node.measured_height = size(style.height, content_height + style.padding.top + style.padding.bottom)
    if style.scroll {
        if style.direction == .vertical {
            if _, grows := style.height.(Grow); grows {node.measured_height = 0}
        } else if _, grows := style.width.(Grow); grows {node.measured_width = 0}
    }

}

@(private)
position :: proc(frame: ^Frame($Content, $Color), index: int) {
    node := &frame.nodes[index]
    if node.first_child < 0 {return}
    style := node.style
    padding := style.padding
    horizontal := style.direction == .horizontal
    available_main := max(0, node.rect.height - padding.top - padding.bottom)
    available_cross := max(0, node.rect.width - padding.left - padding.right)
    if horizontal {
        available_main = max(0, node.rect.width - padding.left - padding.right)
        available_cross = max(0, node.rect.height - padding.top - padding.bottom)
    }
    used: f32
    compressible: f32
    grow_count := 0
    children := 0
    child := node.first_child
    for child >= 0 {
        item := &frame.nodes[child]
        used += horizontal ? item.measured_width : item.measured_height
        sizing := item.style.width if horizontal else item.style.height
        if _, grows := sizing.(Grow); grows {
            grow_count += 1
        }
        if _, fixed := sizing.(Fixed); !fixed {
            compressible += horizontal ? item.measured_width : item.measured_height
        }
        children += 1
        child = item.next_sibling
    }
    gap_total := style.gap * f32(max(0, children - 1))
    used += gap_total
    share: f32
    compression := f32(1)
    if grow_count > 0 && available_main > used {
        share = (available_main - used) / f32(grow_count)
    } else if available_main < used && compressible > 0 && !style.scroll {
        compression = max(0, (compressible - (used - available_main)) / compressible)
    }
    resolved_main := used - compressible + compressible * compression + share * f32(grow_count)
    node.max_scroll = max(0, resolved_main - available_main) if style.scroll else 0
    remaining_main := available_main - resolved_main
    main_alignment := style.alignment.horizontal if horizontal else style.alignment.vertical
    cross_alignment := style.alignment.vertical if horizontal else style.alignment.horizontal
    main_offset: f32
    if main_alignment == .centre do main_offset = remaining_main / 2
    if main_alignment == .end do main_offset = remaining_main
    if style.scroll {main_offset = 0}
    cursor := (horizontal ? node.rect.x + padding.left : node.rect.y + padding.top) + main_offset - clamp(style.scroll_offset, 0, node.max_scroll)
    child_clip := intersection(node.clip, node.rect) if style.scroll || style.clip_content else node.clip
    child = node.first_child
    for child >= 0 {
        item := &frame.nodes[child]
        main := horizontal ? item.measured_width : item.measured_height
        cross := horizontal ? item.measured_height : item.measured_width
        main_sizing := item.style.width if horizontal else item.style.height
        cross_sizing := item.style.height if horizontal else item.style.width
        if _, fixed := main_sizing.(Fixed); !fixed do main *= compression
        if _, grows := main_sizing.(Grow); grows do main += share
        if _, fixed := cross_sizing.(Fixed); !fixed {
            cross = available_cross if cross_alignment == .stretch else min(cross, available_cross)
        }
        if _, grows := cross_sizing.(Grow); grows do cross = available_cross
        cross_position := horizontal ? node.rect.y + padding.top : node.rect.x + padding.left
        if cross_alignment == .centre do cross_position += (available_cross - cross) / 2
        if cross_alignment == .end do cross_position += available_cross - cross
        if horizontal {
            item.rect = {
                x      = cursor,
                y      = cross_position,
                width  = main,
                height = cross,
            }
        } else {
            item.rect = {
                x      = cross_position,
                y      = cursor,
                width  = cross,
                height = main,
            }
        }
        item.clip = child_clip
        position(frame, child)
        cursor += main + style.gap
        child = item.next_sibling
    }
}

intersection :: proc(a, b: Rect) -> Rect {
    x, y := max(a.x, b.x), max(a.y, b.y)
    return {x, y, max(0, min(a.x+a.width,b.x+b.width)-x), max(0,min(a.y+a.height,b.y+b.height)-y)}
}

// Round the two edges, rather than the width, so fractional DPI clips retain their last pixel.
pixel_bounds :: proc(rect: Rect, scale: f32 = 1) -> Rect {
    if !number_valid(scale) || scale == 0 || rect.width <= 0 || rect.height <= 0 {return {}}
    left, top := math.floor(rect.x * scale), math.floor(rect.y * scale)
    right, bottom := math.ceil((rect.x + rect.width) * scale), math.ceil((rect.y + rect.height) * scale)
    pixels := Rect{left, top, right - left, bottom - top}
    return pixels if rect_valid(pixels) else Rect{}
}

rounded_contains :: proc(point: Vec2, rect: Rect, radius: f32) -> bool {
    if rect.width <= 0 || rect.height <= 0 do return false
    if point.x < rect.x ||
       point.x > rect.x + rect.width ||
       point.y < rect.y ||
       point.y > rect.y + rect.height {
        return false
    }
    resolved_radius := clamp(radius, 0, min(rect.width, rect.height) / 2)
    closest_x := clamp(point.x, rect.x + resolved_radius, rect.x + rect.width - resolved_radius)
    closest_y := clamp(point.y, rect.y + resolved_radius, rect.y + rect.height - resolved_radius)
    dx := point.x - closest_x
    dy := point.y - closest_y
    return dx * dx + dy * dy <= resolved_radius * resolved_radius
}

contains :: proc(ui: ^Frame($Content, $Color), index: int, point: Vec2) -> bool {
    if index < 0 || index >= ui.count do return false
    node := &ui.nodes[index]
    return rounded_contains(point, node.clip, 0) && rounded_contains(point, node.rect, node.style.radius)
}

measure_width :: proc(ui: ^Frame($Content, $Color),index: int) -> f32 {
    assert(index>=0 && index<ui.count)
    measure(ui,index)
    return ui.nodes[index].measured_width
}

finish :: proc(frame: ^Frame($Content, $Color)) -> Failure {
    if frame.failure != nil {return frame.failure}
    if frame.depth != 1 {return Unbalanced{}}
    measure(frame, 0)
    frame.nodes[0].rect = frame.viewport
    frame.nodes[0].clip = frame.viewport
    position(frame, 0)
    for node in frame.nodes[:frame.count] {
        if !number_valid(node.measured_width) || !number_valid(node.measured_height) ||
           !number_valid(node.max_scroll) || !rect_valid(node.rect) || !rect_valid(node.clip) {
            fail(frame, Invalid_Dimensions{})
            return frame.failure
        }
    }
    return nil
}
