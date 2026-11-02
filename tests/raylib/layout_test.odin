package tests

import imui "../../src/raylib"

import "core:testing"
import "core:mem"
import rl "vendor:raylib"

@(test)
layout_widths_follow_the_viewport :: proc(t: ^testing.T) {
    frame: imui.UI
    for width in ([3]f32{960,1280,1920}) {
        imui.begin(&frame,width,675,{direction=.horizontal,alignment={.start,.start},gap=12})
        navigation:=imui.layout_leaf(&frame,{width=imui.fixed(213),height=imui.grow()})
        content:=imui.layout_leaf(&frame,{width=imui.grow(),height=imui.grow()})
        testing.expect(t,imui.finish(&frame)==nil)
        testing.expect_value(t,frame.nodes[navigation].rect.width,f32(213))
        testing.expect_value(t,frame.nodes[content].rect.width,width-225)
        testing.expect_value(t,frame.nodes[content].rect.x,f32(225))
    }
}

@(test)
scrolling_preserves_content_and_clips_hits :: proc(t: ^testing.T) {
    frame: imui.UI
    imui.begin(&frame,200,100,{direction=.vertical,alignment={.start,.start}})
    scroll:=imui.column(&frame,{width=imui.grow(),height=imui.grow(),scroll=true,scroll_offset=100,alignment={.start,.start}})
    first:=imui.layout_leaf(&frame,{width=imui.grow(),height=imui.fixed(80)})
    last:=imui.layout_leaf(&frame,{width=imui.grow(),height=imui.fixed(80)})
    imui.close(&frame)
    footer:=imui.layout_leaf(&frame,{width=imui.grow(),height=imui.fixed(20)})
    testing.expect(t,imui.finish(&frame)==nil)
    testing.expect_value(t,frame.nodes[scroll].rect.height,f32(80))
    testing.expect_value(t,frame.nodes[scroll].max_scroll,f32(80))
    testing.expect_value(t,frame.nodes[first].rect.y,f32(-80))
    testing.expect(t,!imui.contains(&frame,first,{10,10}),"Scrolled-away controls cannot receive hits")
    testing.expect(t,imui.contains(&frame,last,{10,50}))
    testing.expect(t,!imui.contains(&frame,last,{10,90}),"The footer clips page controls")
    testing.expect_value(t,frame.nodes[footer].rect.y,f32(80))
}

@(test)
layout_rejects_invalid_or_unbalanced_trees :: proc(t: ^testing.T) {
    frame: imui.UI
    testing.expect_value(t,imui.separator(&frame,rl.WHITE),imui.INVALID_LAYOUT_INDEX)
    testing.expect(t,imui.finish(&frame)!=nil,"A separator needs an open parent")
    imui.begin(&frame,-1,100)
    testing.expect_value(t,imui.separator(&frame,rl.WHITE),imui.INVALID_LAYOUT_INDEX)
    testing.expect(t,imui.finish(&frame)!=nil)
    imui.begin(&frame,100,100)
    imui.column(&frame)
    testing.expect(t,imui.finish(&frame)!=nil)
    imui.begin(&frame,100,100)
    imui.close(&frame)
    testing.expect(t,imui.finish(&frame)!=nil)
    imui.begin(&frame,100,100)
    for _ in 0..<imui.NODE_CAPACITY {imui.layout_leaf(&frame,{})}
    testing.expect(t,imui.finish(&frame)!=nil,"Capacity exhaustion is explicit")
}

@(test)
rounded_hits_match_visible_corners :: proc(t: ^testing.T) {
    bounds:=imui.Layout_Rect{width=100,height=40}
    testing.expect(t,!imui.rounded_rect_contains({0,0},bounds,8))
    testing.expect(t,imui.rounded_rect_contains({50,20},bounds,8))
    testing.expect(t,!imui.rounded_rect_contains({1,1},{},8))
}

// No window or GPU is needed to measure this monospace font.
monospace_font :: proc() -> rl.Font {
    glyphs:=make([]rl.GlyphInfo,256,context.temp_allocator)
    rectangles:=make([]rl.Rectangle,256,context.temp_allocator)
    for &glyph,index in glyphs {glyph.value=rune(index);glyph.advanceX=10;rectangles[index].width=10}
    return {texture={id=1},baseSize=10,glyphCount=256,glyphs=raw_data(glyphs),recs=raw_data(rectangles)}
}

@(test)
wrapped_text_uses_resolved_width_and_rune_boundaries :: proc(t: ^testing.T) {
    frame: imui.UI
    font:=monospace_font()
    imui.begin(&frame,60,200,{direction=.vertical,alignment={.start,.start}})
    node:=imui.paragraph(&frame,font,"one two three",10,rl.WHITE)
    testing.expect(t,imui.finish(&frame)==nil)
    testing.expect_value(t,frame.nodes[node].rect.height,f32(42))
    lines:=imui.text_lines({font=font,value="ééééé",pixel_size=10},20)
    testing.expect_value(t,len(lines),3)
    testing.expect_value(t,lines[0],"éé")
    testing.expect_value(t,lines[1],"éé")
    testing.expect_value(t,lines[2],"é")
    lines=imui.text_lines({font=font,value="one\n\ntwo",pixel_size=10},100)
    testing.expect_value(t,len(lines),3)
    testing.expect_value(t,lines[1],"")
}

@(test)
presented_text_owns_a_copy_of_transaction_rows :: proc(t: ^testing.T) {
    frame: imui.UI
    source: [8]u8
    copy(source[:],"A notice")
    imui.begin(&frame,200,100)
    node:=imui.paragraph(&frame,{},string(source[:]),18,rl.WHITE)
    source[0]='X'
    content:=frame.nodes[node].content.(imui.Layout_Text)
    testing.expect(t,content.value=="A notice","The next input and layout inspection must not retain stack-backed report text")
}

@(test)
fit_labels_leave_remaining_width_for_content :: proc(t: ^testing.T) {
    frame: imui.UI
    font:=monospace_font()
    imui.begin(&frame,400,100,{direction=.horizontal,alignment={.start,.start},gap=12})
    sidebar:=imui.column(&frame,{padding={8,0,8,0},alignment={.start,.start}})
    imui.paragraph(&frame,font,"Navigation",10,rl.WHITE,width=nil)
    imui.close(&frame)
    testing.expect_value(t,imui.measure_width(&frame,sidebar),f32(116))
    content:=imui.column(&frame,{width=imui.grow(),alignment={.start,.start}})
    imui.paragraph(&frame,font,"A paragraph wraps to the remaining space",10,rl.WHITE)
    imui.close(&frame)
    testing.expect(t,imui.finish(&frame)==nil)
    testing.expect_value(t,frame.nodes[sidebar].rect.width,f32(116))
    testing.expect_value(t,frame.nodes[content].rect.x,f32(128))
    testing.expect_value(t,frame.nodes[content].rect.width,f32(272))
}

@(test)
compact_groups_share_the_widest_control_and_center_labels :: proc(t: ^testing.T) {
    frame: imui.UI
    font:=monospace_font()
    imui.begin(&frame,200,100)
    group:=imui.column(&frame,{padding={8,0,8,0},gap=4,alignment={.stretch,.start}})
    controls,labels: [2]int
    for label,index in ([2]string{"A","Widest"}) {
        controls[index]=imui.column(&frame,{padding={12,4,12,4}})
        labels[index]=imui.paragraph(&frame,font,label,10,rl.WHITE,width=nil)
        imui.close(&frame)
    }
    imui.close(&frame)
    testing.expect(t,imui.finish(&frame)==nil)
    testing.expect_value(t,frame.nodes[group].rect.width,f32(100))
    testing.expect_value(t,frame.nodes[group].rect.x,f32(50))
    for control,index in controls {
        bounds:=frame.nodes[control].rect
        label:=frame.nodes[labels[index]].rect
        testing.expect_value(t,bounds.width,f32(84))
        testing.expect_value(t,label.x+label.width/2,bounds.x+bounds.width/2)
    }
}

@(test)
paragraphs_reject_invalid_sizes_and_wrap_at_fractional_width :: proc(t: ^testing.T) {
    font := monospace_font()
    for size in ([3]f32{-1, transmute(f32)u32(0x7fc00000), transmute(f32)u32(0x7f800000)}) {
        frame: imui.UI
        imui.begin(&frame, 100, 100)
        imui.paragraph(&frame, font, "text", size, rl.WHITE)
        testing.expect(t, imui.finish(&frame) != nil)
    }
    frame: imui.UI
    imui.begin(&frame, 100, 100, {direction = .vertical, alignment = {.start, .start}})
    paragraph := imui.paragraph(&frame, font, "aaaa", 0.4, rl.WHITE, width = imui.fixed(0.5))
    testing.expect(t, imui.finish(&frame) == nil)
    testing.expect_value(t, len(imui.text_lines(frame.nodes[paragraph].content.(imui.Layout_Text), 0.5)), 4)
    testing.expect_value(t, frame.nodes[paragraph].rect.height, f32(19.6))
}

// LayoutResolution.BuilderOwnsMeasurement: wrapping is derived, styles remain declarations.
@(test)
wrapping_preserves_declared_sizing_and_prepares_lines_once :: proc(t: ^testing.T) {
    frame: imui.UI
    font := monospace_font()
    imui.begin(&frame, 60, 200, {direction = .vertical, alignment = {.start, .start}})
    paragraph := imui.paragraph(&frame, font, "one two three", 10, rl.WHITE)
    style := frame.nodes[paragraph].style
    testing.expect(t, imui.finish(&frame) == nil)
    testing.expect_value(t, frame.nodes[paragraph].style, style)
    content := frame.nodes[paragraph].content.(imui.Layout_Text)
    testing.expect_value(t, len(content.wrapped_lines), 3)
    lines := raw_data(content.wrapped_lines)
    rect := frame.nodes[paragraph].rect
    testing.expect(t, imui.finish(&frame) == nil)
    testing.expect(t, raw_data(frame.nodes[paragraph].content.(imui.Layout_Text).wrapped_lines) == lines)
    testing.expect_value(t, frame.nodes[paragraph].rect, rect)
}

@(test)
presentation_text_survives_a_scratch_reset :: proc(t: ^testing.T) {
    font := monospace_font()
    presentation_buffer, scratch_buffer: [16384]u8
    presentation, scratch: mem.Arena
    mem.arena_init(&presentation, presentation_buffer[:])
    mem.arena_init(&scratch, scratch_buffer[:])
    context.temp_allocator = mem.arena_allocator(&scratch)
    storage: [3]imui.Node
    frame: imui.UI
    source := [7]u8{'o', 'n', 'e', ' ', 't', 'w', 'o'}
    imui.begin(&frame, 60, 100, {}, allocator = mem.arena_allocator(&presentation), storage = storage[:])
    paragraph := imui.paragraph(&frame, font, string(source[:]), 10, rl.WHITE)
    testing.expect(t, imui.finish(&frame) == nil)
    free_all(context.temp_allocator)
    source[0] = 'X'
    content := frame.nodes[paragraph].content.(imui.Layout_Text)
    testing.expect_value(t, content.value, "one two")
    testing.expect_value(t, content.wrapped_lines[0], "one")
    testing.expect_value(t, content.wrapped_lines[1], "two")
}

@(test)
wrapped_content_obeys_fixed_sizing_and_remains_scrollable :: proc(t: ^testing.T) {
    font := monospace_font()
    frame: imui.UI
    imui.begin(&frame, 60, 20, {direction = .vertical})
    paragraph := imui.paragraph(&frame, font, "one two three", 10, rl.WHITE)
    frame.nodes[paragraph].style.height = imui.fixed(12)
    testing.expect(t, imui.finish(&frame) == nil)
    testing.expect_value(t, frame.nodes[paragraph].rect.height, f32(12))
    imui.begin(&frame, 60, 20, {direction = .vertical})
    scroll := imui.scroll_column(&frame, 0, {width = imui.grow(), height = imui.grow()})
    paragraph = imui.paragraph(&frame, font, "one two three", 10, rl.WHITE)
    imui.close(&frame)
    testing.expect(t, imui.finish(&frame) == nil)
    testing.expect_value(t, frame.nodes[paragraph].rect.height, f32(42))
    testing.expect_value(t, frame.nodes[scroll].max_scroll, f32(22))
}
