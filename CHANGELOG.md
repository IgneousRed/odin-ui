# Changelog

## 0.2.3

1. Fetch the now-public pinned Odin linter in GitHub Actions without a separate
   token. Remove the obsolete missing-secret guard and authentication setup.
2. Update public linter setup instructions and release metadata. Library source,
   public APIs and runtime behavior are unchanged from 0.2.2.

## 0.2.2

1. Consolidate project agent instructions and retain the documented compiler
   vetting and release requirements.
2. Refresh release metadata and the source-copy package for discovery by consumers.
   Library source, public APIs and runtime behavior are unchanged from 0.2.1.

## 0.2.1

1. Keep showcase keyboard input inside its focused canvas. Outside HTML controls
   retain normal activation, typing, Backspace and Tab; blur releases held keys
   and hides canvas focus indicators and the caret.
2. Share portable hit testing, scissor validation and scrollbar geometry between
   the two-pass and compatibility adapters without changing their public APIs.
3. Document host-owned frame failure handling and add a portable runnable example
   covering safe retention, state/viewport invalidation, disabled actions and recovery.
4. Retain drawing and host regression checks in the standard suite. Add an
   optional linked Chromium check for startup, pointer input, focus, editing and
   resize using temporary inspection exports instead of a production API.
5. Share checksum-verified Homebrew web raylib builds while retaining explicit
   SDK/archive overrides. Prepare linked artifacts privately and rebuild corrupt
   cache records as well as corrupt archives.
6. Upgrade the reviewed GitHub-pinned shared Odin linter to 0.7.1 at commit
   `949293b8a7fcff8f72927b5afb5c5ada8b2df896`; preserve all compiler and lint gates.
7. Publish each new main commit as the latest public release, keeping local
   verification and GitHub Actions status explicit.

## 0.2.0

1. Added explicit layout builders, generation-checked node handles, resolved views
   and immediate ordered paint operations. Geometry and prepared text are reused
   without copying the tree; appearance remains outside geometry.
2. Prepared text runs, wrapping, line positions and field cursor tables during
   layout. Painting and caret blinking perform no Odin allocation or measurement.
3. Migrated the showcase and source-copy consumer to the two-pass interface;
   retained the combined API for existing external consumers. Added migration
   guidance to the source-copy archive.

## 0.1.3

- Keep a field's cursor position, text and selection aligned inside constrained
  widths, including UTF-8, multiline values and blinking carets, without adding
  interaction state.
- Let Tab leave the web showcase canvas through normal browser focus navigation.

- Upgrade the GitHub-pinned shared Odin linter to 0.7.0 with staged installation
  and synchronized runner/lock documentation.
- Use tab indentation throughout first-party Odin sources so maximal vetting and
  strict-style compiler gates can run without weakening their scopes or flags.
- Inline the sole-use padding validation and positioning procedures after
  checking evaluation order, generic frame scope and public API preservation.

- Limit eleven already-private layout/raylib helpers to their source files,
  preserving public exports, signatures, bodies and useful semantic boundaries.

- Bound stale scroll offsets before wheel input and capture, avoiding a dead zone
  when dragging or scrolling back from a reduced content extent.
- Round calculated color channels to the nearest byte, preserving RGB/HSL round
  trips and blends of a color with itself instead of losing channel values.
- Wrap HSL hue angles in both directions and interpolate alpha in HSL blends.
- Preserve small positive paragraph heights by counting line gaps directly.
- Use measured label/control dimensions as intrinsic sizes for explicit grow sizing;
  reject invalid measurements even when callers override both dimensions.
- Reserve fixed children and gaps before compressing fit/grow content, preserving
  the available space even when intrinsic sizes are much larger than the viewport.
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

## 0.1.2

- Organize library, showcase and test declarations into explicit import, kind and
  visibility sections; preserve declaration bodies and public library APIs.
- Give each test package a distinct matching directory and one interface, while
  retaining the complete headless and packaged-consumer verification suite.
- Honor an explicit `ODIN` compiler selection in the packaged-source consumer
  checks, retaining ordinary consumer commands and target flags.

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
