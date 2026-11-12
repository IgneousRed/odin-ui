# TODO

1. [ ] Repair and verify GitHub Actions before the next publication.
   `ODIN_LINT_GITHUB_TOKEN` is unset, so the private-linter prerequisite stops
   checks before compiler/lint execution. Configure a read-only Contents token
   for `IgneousRed/odin-lint`, rerun [the failed v0.2.0 commit run](https://github.com/IgneousRed/odin-ui/actions/runs/43197590809),
   and require successful CI for the exact pushed commit before reporting remote
   verification or publishing a release. Add a checked release gate that detects
   failures, missing runs and unconfirmed results. Deferred at the user’s request;
   local verification does not establish a CI pass. Confidence: 10/10.

2. [ ] Agree with the user on an external reviewer and the changes that require
   external review. The two requested sol-finish loops have completed; no general
   external-review gate is configured or required by project instructions.
   Confidence: 8/10.
