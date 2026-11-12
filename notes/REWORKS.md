# Rework proposals

These are unapproved follow-ups, ordered by confidence and expected return.
Application persistence and application-store architecture are excluded by AGENTS.md.

1. **Prepared codepoints for remaining measurement paths. Confidence: 8/10.**
   Normal two-pass fields already prepare runes and byte-indexed cursor positions
   during layout. Legacy `draw` still decodes full text and measures prefixes for
   overlays; wrapping measurements also decode overlapping strings. A compact
   prepared run could remove that repeated work. Keep its data reconstructible
   and attached to the existing nodes. The cost is a larger payload and more
   lifetime/API rules. Reconsider when profiling a real consumer shows those
   remaining paths are material after the existing prepared-line changes.
2. **Hybrid or SoA node storage. Confidence: 6/10.**
   The current AoS stores cold drawing data beside hot layout data. Splitting
   columns may improve locality. A tested hybrid preserved geometry, but changed public node access and complicated
   builders, generic frames and consumers. Reusable caller storage already avoids
   allocation/clearing for small screens, and construction-only links no longer
   consume per-node space. Reconsider with a representative consumer profile that
   shows layout memory traffic, rather than text work, is the limiting cost.
