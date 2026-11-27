# Changelog

## 0.2.11

1. Adopt the published shared native dependency unit and Odin linter revision
   `8643e84c9d56ed02ff3cfd75a3aad717447ae9d7`. Preserve compiler, SDK and ABI
   boundaries and reuse the existing shared Node 26.13.1 output.
2. Update the coupled Emscripten SDK to 7.0.1 and Playwright to 1.65.1 with its
   matching Chromium bundles; retain the shipped WebKit and FFmpeg revisions.
3. Keep dependency reports complete after truncated HTTP responses, reject
   symlinked parent components before staging declared Nix inputs while retaining
   intentional project-root aliases and regular nested paths with spaces, and
   honor `NIX_BUILD_CORES` in the `odin-fuzz` Nix build recipe.
4. Library sources, public APIs and runtime behavior are unchanged.

## 0.2.10

1. Publish a fresh source snapshot without previous Git ancestry or release tags.
   Keep instruction files private and exclude them from public inputs/exports.
2. Adopt pinned Odin linter 0.7.7 and Nix-native odin-fuzz 0.4.0; remove the
   obsolete compatibility patch while retaining lazy tools and coverage gates.
3. Library sources, APIs and runtime behavior are unchanged from 0.2.6.

## 0.2.9

1. Purge reclassified private records from owned public main and release-tag
   history. Preserve existing clean source-copy ZIP assets unchanged.
2. Enforce explicit outgoing publication refs and reject reserved paths and
   copied private records throughout their ancestry. Exclude `.vendor/` views.
3. Adopt the content-equivalent sanitized Odin linter 0.7.6 source identity,
   canonical compiler-check resource controls, strict locked evaluation and
   origin-safe dependency-update redirects. No dependency-version upgrade.
4. Library source, public APIs and runtime behavior are unchanged.

## 0.2.8

1. Keep open task records in the private companion and remove current public
   TODO references without introducing private dependencies into public setup.
2. Extend publication checks to the approved private folders and reject public
   TODO records. Document the restriction on retained consumer source/data
   snapshots while preserving allowed own-project and provenance evidence.
3. Library sources, APIs and dependency pins are unchanged. Published history,
   release tags and assets are preserved.

## 0.2.7

1. Supply locked Nix development tools with shared immutable compiler, linter,
   SDK and browser packages. Darwin uses LLVM 23 and rebuilt Python 3.15; preserve
   Linux and Emscripten compatibility boundaries. Keep optional fuzz tooling lazy.
2. Keep public sources independent of private research notes and local data.
   Exclude reserved paths from publication and retain reusable fuzz data locally.
3. Generate builds in `.work/build/` and verified source-copy archives in
   `.work/package/`; remove obsolete captures and package copies after use.
4. Library sources, public APIs and dependency versions are unchanged by this
   reorganization. Verification runs locally without a hosted-CI prerequisite.

## 0.2.6

1. Remove both GitHub Actions workflows and all hosted-CI requirements. Run
   compiler, tests, lint and optional fuzz exploration locally.
2. Update release/development instructions and prerequisite-reuse help. Local
   verification protections, library sources and public APIs are unchanged.

## 0.2.5

1. Add deterministic headless showcase replay through the shared input, editing,
   layout and painting path, including separate mutable text/focus/touch events.
2. Drive the failure-policy example from bounded scenarios. Correct its zero-width
   hit/capture assumption and retain the original seven-case demonstration.
3. Pin odin-fuzz with checksum-verified setup, persistent corpus reuse, per-launch
   LLVM feedback checks, retained reports and an optional manual macOS workflow.
   Match LLVM tools to the selected compiler's reported backend.
4. Upgrade the reviewed shared Odin linter to 0.7.6 at commit
   `1560b45496f66a2d65a2b38add62d91fd20c462a`, retaining all 27 rules.
5. Add replay and coverage-gate regressions. Forward explicit compiler arguments
   through checks and example builds without changing default compiler settings.
   Library public APIs and runtime source are unchanged from 0.2.4.

## 0.2.4

1. Keep paragraph fit/grow sizing correct when geometry is revised during layout.
2. Align field carets and selections with raylib glyph drawing advances in both
   APIs, including zero-advance glyphs and line ends. Share legacy button drawing.
3. Upgrade the reviewed shared Odin linter to 0.7.4 at commit
   `b5a1f251f837e6f3e4e4d2f10aa13f9bb9258553`. Reuse compatible cached binaries
   across projects while preserving exact pins, isolated inputs and all checks.
4. Consolidate web toolchain setup and compiler-policy documentation. Clarify
   fresh source-archive setup and manual vendoring, including the migration guide.

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
