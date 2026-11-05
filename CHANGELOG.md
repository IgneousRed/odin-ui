# Changelog

## Unreleased

- Truncate to the longest fitting UTF-8 prefix even when shaping makes candidate
  widths nonmonotonic or makes the suffix alone wider than a combined candidate.
- Omit field underlines when the resolved width cannot contain their text padding.
- Bound rounded-control tessellation before integer conversion for oversized controls.
- Include shell-script syntax validation in the standard check suite.
- Preserve rounded hit regions and drag thresholds at extreme finite scales.
- Place field selections and carets within their own lines for multiline values.
- Finalized frames reject subsequent builder/action changes until `begin`;
  failed or unfinished frames cannot supply hits. Repeated `finish` is read-only.
- Make trigger assignment and hit testing available in the portable layout package.
- Let both layout and raylib `begin` accept an allocator and reusable node storage;
  add optional output allocators to the portable text helpers.
- Prepare wrapped lines once without rewriting declared sizing. Fit paragraphs now
  obey compression in constrained non-scrolling containers; scrolling retains their
  full measured height. Normalize paragraph whitespace using one reusable buffer.
- Remove `Node.parent`, `Node.last_child`, `Style.has_background` and
  `Layout_Rectangle`. Use `Style.background` for ordinary rectangular fills;
  `Layout_Bar.background` also moves to the node style. Builder stack entries now
  contain `index` and construction-only `last_child`.
- Separate device sampling from portable pointer transitions; make showcase state
  caller-owned, reuse its node storage and collect queued text in one buffer.
- Build both showcases with debug information, check web symbols strictly against
  explicit Odin runtime imports, and generate verified release checksums.
- Fields and their drawing content use `text.Selection` for both the highlighted
  range and caret position. Replace `selection_start`, `selection_end` and
  `cursor_position` with `selection = {anchor, cursor}`; replace the field's
  `select_all` flag with `{0, len(value)}`. The `cursor` visibility flag remains.
- Remove the raylib adapter's `Layout_Frame` alias; use `UI`.
- Remove `Style.scroll_path` and the path argument from `scroll_row` and
  `scroll_column`. Use `action` to identify scroll containers through node triggers.
- Remove the unused `has_hold` button option and drawing-content field.
- Keep the caret visible in empty focused fields.
- Reject overflowing resolved rectangle edges and unrepresentable scissor bounds.

## 0.1.1

- Use `vendor/odin_ui/` consistently in installation examples and consumer checks.
- Clarify fixed-version updates, checksum verification, build/watch integration,
  and retaining the MIT license with redistributed builds.
- No library API or behavior changes.

## 0.1.0

First public release. The API is evolving; compatibility is not promised across
minor releases before 1.0.

- Portable layout, measured text wrapping/editing, and caller-owned input state.
- Optional raylib adapter for drawing, controls, clipping and pointer input.
- Desktop and WebAssembly showcase hosts.
- Source-copy installation with a small release archive and update instructions.
- MIT license for the library; the showcase font retains its SIL Open Font License.
- Allium contract checks, headless tests, native/Wasm type checks, and a consumer
  build from the actual release archive.

Native iOS integration, grapheme-cluster editing, shaping, clipboard I/O and IME
services are not supplied by this release. Applications own their platform
integration and persistent state.
