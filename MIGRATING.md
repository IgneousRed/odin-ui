# Migrating to the two-pass interface (0.2.0)

1. Replace `UI` with a stationary `Layout_Builder`, `Node` storage with
   `Layout_Node`, and keep a `Resolved_Layout` for input against the presented
   frame. Reuse caller-owned node arrays and a frame arena; consume previous-frame
   input before reusing either.
2. Replace `begin` with `begin_layout`. Use `row_layout`, `column_layout`,
   `close_layout`, `box_layout` and the widget `*_layout` operations. Retain every
   returned `Node_Handle` needed for painting or hit testing. Move backgrounds,
   border colors and scrollbar colors out of geometry into application drawing
   data. Keep padding, radius, scroll offset and clipping in `Geometry`.
3. Supply all text, font metrics and wrapping during declaration. Use
   `Text_Options` for label/control dimensions. `paragraph_layout` accepts
   `centered` and `width`; its default width grows. Fixed controls clip overflow.
   Use `set_geometry` to revise a declaration before resolution, and
   `measure_layout_width` for intrinsic group widths. These replace direct edits
   to builder nodes.
4. Replace `finish` with `resolved, failure := finish_layout(&builder)` and check
   the failure before presentation. Inspect rectangles and scroll limits with
   `geometry(resolved, handle)`. For inspection tools, iterate `layout_count` and
   `layout_handle`, and read labels with `layout_text`. Treat all library storage
   as opaque. `set_geometry` and `layout_action` reject resolved builders.
5. Between passes, query `contains_resolved` and `hit_resolved`. Retain stable
   control IDs for focus/capture, and keep activation separate from disabled
   appearance. Handle generation checks reject old frames and other surfaces.
6. Replace `draw` with `begin_paint`, explicit `paint_*` calls and `end_paint`.
   Supply foreground colors explicitly. Paint scrollbars after content where
   desired. Border and focus colors are optional transparent defaults. Field paint
   takes `selection`, `selection_background` and `cursor`. It uses prepared
   codepoint positions; caret blinking does not reposition text or remeasure it.
7. Replace post-finalization hover mutations with a fill chosen at paint time.
   For a custom button composed from a column and paragraph, paint its box first
   and its paragraph second. One fill is sufficient. Applications can retain
   per-handle drawing records outside the geometry tree when composition and
   presentation occur in separate procedures.
8. Call paint operations in the desired order for every surface. A typical host
   paints its main screen, a modal backdrop, its dialog, then its tooltip. No
   operation reorders commands. Commands use both node bounds and ancestor clips.

The compatibility API is retained for source consumers; migration can happen
surface by surface. Never mix handles with compatibility integer indexes. Empty
paint passes and zero-initialized absent resolved surfaces are valid no-ops.
Every builder must outlive its handles and views at the same address. Starting
another layout invalidates all previous views from that builder. Do not share a
node slice or reset its arena while a live presentation still borrows it.

The normal path performs no Odin allocation or text measurement during painting.
Preparation owns frame-lifetime storage. Field cursor tables accumulate glyph advances during layout without measuring
every prefix; paint remains linear in the number of prepared lines. The maintained capture and
allocation tests exercise clipping, command order, single fills, UTF-8 selection,
caret blinking, stale/cross-frame handles and repeated reusable frames.
