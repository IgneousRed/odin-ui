# Rework proposals

These are unapproved follow-ups, ordered by confidence and expected return.
Application persistence and application-store architecture are excluded by AGENTS.md.

- **Prepared codepoints for repeated text measurement. Confidence: 8/10.**
  `src/raylib/raylib.odin` still decodes overlapping text during measurement and
  field overlays. A compact frame-local prepared run could remove repeated UTF-8
  conversion. Keep its data reconstructible and attached to the existing nodes.
  The cost is a larger drawing payload and more lifetime/API rules. Reconsider
  when profiling a real consumer shows text decoding remains material after the
  wrapping-buffer and prepared-line changes.
- **Pure geometry for field overlays and scrollbars. Confidence: 7/10.**
  `draw` mixes these calculations with raylib calls. Extract a cohesive pure
  calculation when it enables a useful headless reproduction. This removes the
  need for a window to inspect a geometry defect, but introduces another result
  representation. Reconsider when a drawing defect needs such a reproduction;
  do not create helpers for individual arithmetic expressions.
- **Hybrid or SoA node storage. Confidence: 6/10.**
  The current AoS stores cold drawing data beside hot layout data. Splitting
  columns may improve locality. A tested hybrid preserved geometry, but changed public node access and complicated
  builders, generic frames and consumers. Reusable caller storage already avoids
  allocation/clearing for small screens, and construction-only links no longer
  consume per-node space. Reconsider with a representative consumer profile that
  shows layout memory traffic, rather than text work, is the limiting cost.
