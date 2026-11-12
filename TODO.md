# TODO

1. [ ] Repair and verify GitHub Actions.
   `ODIN_LINT_GITHUB_TOKEN` is unset, so the private-linter prerequisite stops
   checks before compiler/lint execution. Configure a read-only Contents token
   for `IgneousRed/odin-lint` and rerun [the failed main run](https://github.com/IgneousRed/odin-ui/actions/runs/43233274144).
   Require a successful run for the exact pushed commit before reporting remote
   verification; detect and report failures, missing runs and pending results.
   Deferred at the user's request. Publication follows the main/latest rule in
   AGENTS.md and is not blocked by this deferred setup. Local verification does
   not establish a CI pass. Confidence: 10/10.

2. [ ] Agree with the user on an external reviewer and the changes that require
   external review. The two requested sol-finish loops have completed; no general
   external-review gate is configured or required by project instructions.
   Confidence: 8/10.
