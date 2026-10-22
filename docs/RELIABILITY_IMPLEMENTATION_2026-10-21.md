# Playback reliability and engineering review - 2026-10-21

Follow-up: [native telemetry, repair lifecycle and casting entropy](RELIABILITY_FOLLOWUP_2026-10-21.md) now supersede the corresponding open items below.

## Scope and judgment

The supplied review has the right product priority: diagnose playback before
adding integration breadth. Its original evidence was static and not pinned to
one commit. This assessment is pinned to HEAD `3080da6d039c1b7ab2ff95fb15a94743ad245998`
plus the working changes listed below. Existing unfinished 1.27 changes were
preserved; they are not part of this implementation or a new release claim.

The proposal is a roadmap, not evidence that cessation, RAR4, arbitrary MCP
execution or updater compromise has been reproduced. Existing playback, history,
metadata and playlist capabilities must not be presented as newly invented.
The v1.16 notes are historical; the current source already contains later resume,
trailer and library fixes.

## Findings and disposition

| Finding | Current evidence | Result |
|---|---|---|
| P1: URL and redirect boundary | New offline regressions first failed for accepted userinfo and HTTPS downgrade. Manual splitting also mishandled query-only targets, IPv6 and relative references. | Fixed with pinned maintained `url` 2.5.8 parsing/joining, raw control/whitespace/backslash rejection, userinfo rejection and downgrade prevention. |
| P1: configured indexer key on another origin | Download code appended the configured key to any feed URL missing an apikey parameter. No live exploit was attempted. | Fixed: automatic key insertion requires the exact configured origin. External public CDN URLs retain only credentials already supplied by their source. |
| P1: redirected requests into local networks | The old client did not check resolved destinations. Deliberately configured LAN indexers are legitimate. | Fixed: resolve/check each destination, connect only to checked addresses, restrict private destinations to the exact configured origin and its initially resolved addresses. Link-local, unspecified, multicast and selected special ranges are denied even for a configured origin. |
| P1: insufficient cessation evidence | No new cessation or RAR4 fixture was provided or reproduced. | Playback Doctor foundation added. Root-cause and engine-wide telemetry acceptance remain open. |
| P1: update integrity versus publisher identity | Current updater verifies same-release hashes. That does not independently authenticate the publisher. | Existing behaviour preserved; signed manifest/publisher implementation remains blocked on a real trust root, certificate and rotation/rollback decisions. No test key is shipped as a production trust root. |
| P2: MCP authority/cancellation | Runtime already rechecks permissions; opt-in pause/resume/seek already exist. External requests already use abortable HTTP; local Future.timeout does not cancel a callback. | No new tools or autonomous permissions added. Local cooperative cancellation remains required before adding deferred write/download/export capabilities. |
| P2: coupled release preparation | Combined release still requires all platform jobs. Individual builders alone did not couple a selected build to shared verification and a candidate manifest. | Added an independent platform-candidate workflow. Combined publication and updater channels are unchanged. |

## Implemented: outbound HTTP and download hardening

Changed `rust/src/engine/http.rs`, `rust/src/api/search.rs`, Cargo.toml and
Cargo.lock. No public bridge signature changed and no generated bridge files
were edited. The URL dependency and its transitive lock entries are the only
dependency additions; no general upgrade was performed.

Raw unsafe input is rejected before URL normalization can erase evidence.
Fragments are excluded from request targets; IPv6 literals receive bracketed
Host headers and unbracketed socket/TLS hosts. Redirects support relative paths,
query changes, dot segments and scheme-relative references. Neither the current
HTTPS request nor an HTTPS configured origin can downgrade to plaintext.

A configured indexer's base URL is the explicit LAN-origin grant. Resolving that
origin establishes a bounded request's allowed LAN addresses. Each actual
connection resolves the destination and checks every answer; a redirect cannot
expand the LAN grant by changing origin or DNS answer. The connection uses that
checked address list, avoiding a second DNS resolution at connect time. NZB
URLs obtained from feeds use their configured indexer origin for this policy,
not the feed URL as a new grant. Public cross-origin CDNs remain supported;
configured API keys are not appended outside the configured origin. Existing
provider-supplied signed URLs are not rewritten or logged.

This remains a small HTTP/1.1 client, not a complete migration to a maintained
HTTP stack. Platform proxies, every unusual network translation mechanism and
all protocol edge cases are not certified. Explicit LAN grants are host/port
configuration, not a newly implemented per-network permission UI. DNS answers
can still change between separate user requests; each new request establishes
its configured origin's grant again.

## Implemented: Playback Doctor foundation

Open the player's advanced controls and choose **Playback Doctor**, or use the
button on its error screen. The report observes preparation/selection,
connection plus stream preparation, decoder readiness, the controller's actual
first-frame notification, playing/paused transitions, buffering, explicit seek
commands, startup timeout and existing repair callbacks. Playback continues
when this screen is opened.

Only typed events, attempt numbers and monotonic durations enter the report.
It has a 128-event ring and a dropped-event count. It never accepts raw log or
exception strings as report fields. There are no titles, filenames, paths,
source/indexer URLs, API keys, cast tokens, NZBs or media in the report.
Nothing is sent or persisted automatically. Preview freezes the JSON; Copy
exports exactly that preview after an explicit action. Failed clipboard access
is surfaced. New diagnostic copy uses the English fallback.

Startup buffering and buffering while paused do not inflate rebuffer time.
Decoder readiness is distinct from an actual frame. First-frame timing uses the
video controller's first-render signal, which is once per controller lifetime;
a later retry does not reuse that completed signal as a fake new measurement.
Seek events measure command completion, not a confirmed visual seek latency.
The report provides observations for future baselines; it does not claim median,
p95, crash-free sessions, successful resume rates or proven cessation causes.

Reported error classification is deliberately coarse and can remain unknown.
The application cannot currently separate every retry, missing segment, range
request, archive decode or repair transition inside Rust through this report.
Those need typed per-session engine events and bridge integration. There is no
claim that every silent cessation can already be classified. Existing repair
startup/polling cancellation paths also need an independently testable lifecycle
before extending them into a recovery orchestrator.

## Implemented: independent platform candidates

`.github/workflows/platform-candidate.yml` takes an existing version tag and one
platform. It resolves the tag once, validates release inputs, runs the shared
verification workflow and invokes only that platform's existing builder using
the resolved SHA. It inherits signing secrets only for the Android builder.
No unrelated platform builder can prevent a selected Windows build.

Candidate assembly rejects missing/unexpected package inventory. It records
source SHA, workflow SHA, source tag, platform, run URL and explicitly unverified
installation/device/signing gates in SOURCE.json. SHA256SUMS covers packages and
provenance. It uploads a candidate artifact, with read-only repository
permissions; it does not create a tag or release, merge, install or publish.
This removes coupling for preparation, not stable-channel eligibility or final
promotion. See the updated [release runbook](RELEASING.md).

## Verification

Fresh ordered application gate on this working tree:

1. Rust tests: **277 passed**, serial.
2. Clippy all targets with warnings denied: passed.
3. Flutter analysis of lib and test: passed, no issues.
4. Host native build: passed, supplying the DLL for bridge tests.
5. Flutter suite: **426 passed**, **10 opt-in skips**.
6. Whitespace: passed.

The gate includes pre-existing working changes but does not validate their live
providers or certify them for release. Initial gate attempts stopped on a test
read-count lint and seven brace-style analysis infos; corrected before the
passing gate. The original two URL regressions were observed failing before
the fix. The HTTP subset now has 15 passing tests, including actual local
redirect rejection before connecting to the forbidden destination, safe request
formatting, IPv6, relative resolution and DNS/address policy checks. The download
key-origin regression is also covered.

Four focused Playback Doctor tests passed: startup/paused buffer accounting,
privacy/event bounds/disposal, frozen preview and clipboard export, and a
390-pixel layout at 180% text size. Actionlint 1.7.12 passed the new workflow.
Its embedded manifest code was compiled and exercised with four synthetic
platform package inventories, verified checksums/provenance, and missing-package
rejection. No GitHub workflow run or live platform build is claimed.

Logs: ignored `dist/audit/reliability-*` and `dist/audit/review-*`.
No new installer, native rendered preview, signature, device playback, casting,
clean-install check, commit, push or published release is claimed for this work.

## Remaining work and promotion gates

1. Obtain a sanitized reproduction/redistributable fixture for cessation and
   the reported RAR4 case; reproduce before changing archive parsing. Preserve
   decoded yEnc offsets and bounded streaming/cancellation invariants.
2. Add typed per-session Rust range/segment/retry/decode/repair events, bounded
   aggregation and cancelled-session cleanup; extend Doctor only with observed
   facts. Do not infer codec support or complete release availability from names.
3. Build recovery around tested lifecycle/cancellation seams: current session
   checkpoint, eligible bounded retries, explicit backup-provider choice, PAR2
   sufficiency and user-selected alternate release. Never silently transfer
   timestamps between different edits.
4. Provision publisher signing and choose a separately trusted manifest key,
   rotation/revocation and minimum-version/rollback policy. Then implement and
   test wrong-publisher, changed manifest/artifact and rollback rejection.
5. Define MCP call scopes/deadlines and cooperative cancellation at effect
   boundaries, per-client grants and redacted audit records before adding new
   writes. Discovery or metadata cannot confer authority. Revocation must be
   rechecked after queued waits and immediately before an effect.
6. Execute clean-user install/upgrade, start/seek/resume/repair/cast and remote-
   only/screen-reader checks per claimed platform. Run the new candidate workflow
   against the reviewed/tagged source before claiming CI evidence.
7. Only then select one optional watch-state/subtitle integration for a validated
   contract. Encrypted sync, Notion exports, marketplaces and additional AI
   providers remain proposals, not implemented features of this change.

## Primary references

- [url 2.5.8 parsing and joining](https://docs.rs/url/2.5.8/url/struct.Url.html):
  maintained URL semantics; application policy still needs separate validation.
- [MCP cancellation](https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/cancellation):
  cancellation notifications are optional/cooperative, not a promise that timing
  out a Future cancels its side effects.

These sources support API semantics, not a new proof of native playback or a
Zanzibarr exploit. The supplied paper/context does not establish app-specific
performance thresholds, and none are asserted here.
