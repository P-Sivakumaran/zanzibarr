# Review of completed working changes

Baseline: `3080da6d039c1b7ab2ff95fb15a94743ad245998`. Reviewed tracked
working changes and relevant untracked source against AGENTS.md and the dated
reliability, research/menu and series-navigation implementation documents.

Scope: HTTP/download trust boundaries, native and player diagnostics, repair
lifecycle, casting entropy, cooperative MCP cancellation, platform candidates,
optional web research, player menu contrast, series navigation and user costs.

## Standards

**One confirmed P2 finding, corrected:** cancelled or expired MCP calls released
their HTTP slot while the underlying callback could continue. Repeated
cancellation could accumulate unbounded native/indexer work. Each server now
counts actual running callbacks separately and retains their slots until those
futures settle. Cancellation still returns promptly. Regressions saturate the
operation budget through cancellation and expiry, reject another operation,
then verify capacity returns when an underlying callback finishes. This limit
is per server; endpoint replacement can overlap old read-only work.

Re-review found no additional blocking issue in the reviewed native HTTP/DNS,
credential-origin, cast entropy, bounded telemetry, publisher helper or workflow
changes. Existing decoded-offset and native archive fixes are preserved. No
substantive code-smell finding justified an unrelated refactor.

## Spec

**Two confirmed P2 findings, corrected:**

1. The exact-episode matcher accepted `1x01` names but rejected multi-episode
   ranges only in `S01E01` form. NxNN ranges/chains now stay manual and cannot
   pass player episode-handoff validation. Four negative forms and a positive
   single-episode form are covered.
2. Any surviving citation caused all research prose to enter formatter context.
   Formatter notes now contain only cited Claude text blocks or Gemini-supported
   segments with valid source links. Original provider text remains separate for
   display/Google attribution. Mixed cited/uncited and invalid-source fixtures
   cover the correction; research size limits remain enforced.

Re-review found no further substantive issue in these corrections. Opt-in release
ranking remains a size/runtime/connection-budget estimate, not a live throughput,
segment-availability or decoder guarantee. Episode names, stills and synopsis
preferences remain independent; summaries default hidden.

## Commit boundary and validation

The unfinished v1.27 hosted catalog is excluded and preserved on disk: catalog
sources/screens/tests/docs/screenshots, Home/catalog route replacement, adult
source UI changes, packaging additions and root version bump. Only the Series
entry is staged from the mixed Settings file. The committed pubspec retains the
baseline version; historical v1.28-v1.30 builds used explicit isolated candidate
versions. This commit is not a new release or installer build.

Focused regression tests: **72 passed**. An isolated export of staged tree
`0c98c8367fa67a71b11e7b0e6d47969ab9f7e120` passed the fresh ordered application
gate: **280 Rust tests**, Clippy with warnings denied, Flutter analysis with no
issues, native host build and **498 Flutter tests** (**9 optional skips**).
Excluded WIP therefore cannot mask a missing dependency. Only documentation was
updated after that export. Final staged and working whitespace checks passed.
Logs: ignored `dist/audit/commit-{rust,clippy,analyze,native,flutter}.log`.

Workflow actionlint and publisher-helper regressions passed. The helper tests
mock trust decisions and reject an actual unsigned fixture; they do not establish
publisher signing. No application installation, process shutdown, real-provider
call, GitHub push or publication was performed during this review.

Signing/trust roots, cessation/RAR4 reproduction, live provider transitions,
clean-user installation, casting and physical-device/accessibility validation
remain open. Existing installers predate the three review corrections above.

Summary: Standards 1 finding corrected; Spec 2 findings corrected. No remaining
blocking finding in the reviewed scope, subject to the explicit validation limits.
