# Reliability follow-up - 2026-10-21

This supersedes the native-telemetry and repair-lifecycle limitations in the
[first reliability pass](RELIABILITY_IMPLEMENTATION_2026-10-21.md). Base remains
HEAD 3080da6 plus preserved working changes. No unfinished catalog file was
removed, committed, pushed or released.

## Implemented and verified

### Native playback observations

A typed native trace now follows a stream session through selection, archive or
stream preparation, range-body reads, NNTP segment requests, segment decoding,
network/yEnc failures, connection-limit retry, cancellation and task completion.
The code records observations where work happens, not file-name inference.

The current task scope is captured by source contexts and propagated into HTTP
child tasks, so request-owned prefetch and range work keep the correct session.
Each trace holds at most 128 events; only four recent sessions are retained.
Finished traces ignore late events. No arbitrary message, URL, filename, source
identity, article ID, NZB, credential, cast token or media enters this schema.
Native timing is relative to native session creation; player and native clocks
are separate and labelled accordingly. Range events represent body reads, not
HEAD requests, rejected requests or proof that a frame was rendered.

A new bounded snapshot API crosses the Rust/Dart bridge into Playback Doctor.
The player polls at most once per second without overlapping polls and accepts
only known event codes. Cleanup waits at most 250 ms for a final snapshot;
diagnostics cannot hold teardown indefinitely. Native read failures are ignored
by playback. Snapshot history is cleared for a new attempt. There is no automatic
upload or persistence, and copied reports retain the existing explicit preview.

The bridge was regenerated with flutter_rust_bridge_codegen **2.12.0**, using the
repository's Rust input/root and Dart output. Rust auto-formatting was disabled
in the generator to prevent unrelated recursive edits; generated Rust alone was
formatted afterwards. Generated files were not hand-synchronized.

Coverage is not a promise to expose every compressed-archive internal decoder
step. The report surfaces actual observed boundary failures and can still leave
a root cause unknown. It does not sample release completeness, estimate codec
support from names or make availability guarantees.

### Repair lifecycle

`RepairCoordinator` now owns starting/running/succeeded/failed/cancelled states,
the session ID, generation, polling and cleanup. It catches settings/startup,
progress and result failures. Progress polls cannot overlap. Cancellation during
settings loading is checked immediately before native begin. If begin was
already issued, a late session ID is cancelled. Cancellation after a session
arrives prevents result processing and reopening. Dispose does the same.

Late progress/results cannot update a cancelled or newer attempt. Polling failure
cancels the native session, yields a sanitized error and suppresses late success.
Only a successful current repair can reopen the exact same release/media entry;
existing durable history owns resume. No timestamp is transferred to another
release or edit, and no backup-provider cost is incurred automatically.

Six deterministic coordinator regressions cover startup retry, pending-ID
cancellation, non-overlapping polling, poll failure plus late success, disposal,
cancellation during settings loading and cancellation from a state listener.
They exercise different cancellation boundaries; no actual NNTP account is used.

### Casting capability entropy

The previous cast capability was derived from time, process ID and session ID.
It now uses 16 fresh bytes from the OS RNG through the already locked getrandom
0.2.17 package. Direct dependency declaration and lock references are aligned.
Entropy failure returns no capability and does not open a LAN listener. Local
playback remains available. The token is never exported in diagnostics.

A regression checks token shape/freshness and the entropy-failure result. Existing
server token/range and shutdown regressions remain in the full suite. No live
physical casting or exploit attempt is claimed.

### Publisher verification preparation

`tools/windows/verify-publisher.ps1` requires a Valid Authenticode status and an
exact allowed certificate thumbprint. Invalid signatures, absent certificates
and other publishers fail closed. Thumbprints identify trusted certificates;
they are not a claim that SHA-1 is used to sign the binary.

Reproduce policy checks with:

```powershell
./tools/windows/test-publisher.ps1 -UnsignedArtifact dist/preview-1.26/zanzibarr.exe
```

One matching mock is accepted; wrong-publisher, tampered and unsigned mocks are
rejected. The actual unsigned 1.26 executable is also rejected through the real
OS signature query. Mock checks test policy decisions, not the real chain of an
unavailable publisher certificate. The current-user certificate store contains
**zero usable code-signing certificates**, checked during the preceding follow-up without exporting
private key or certificate details.

This helper is not wired in as a claim of signed automatic updates. Production
signing and a separately trusted signed manifest still require the owner's real
certificate/public trust root, rotation/revocation and rollback decisions. No
certificate or production signing key was fabricated, and no test root is
trusted by the application. Existing unsigned update behaviour was preserved.
[Microsoft Authenticode API documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-authenticodesignature).

### MCP cooperative cancellation

After the user's approval to continue, the narrower proposal was implemented.
Each local tool call owns a monotonic 30-second deadline and a cancellation
signal. Authenticated cancellation notifications target only an active typed
request ID in the existing bearer scope. Unknown, malformed and completed IDs
are ignored; initialize is not cancellable. Duplicate active IDs are rejected,
including reuse for another method. Explicit cancellation closes the original
HTTP request with 202 and no JSON-RPC response, following the
[official cancellation guidance](https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/cancellation).

Endpoint close/configuration/token change cancels active scopes. Requests still
reading their body recheck shutdown before dispatch. Timer/map cleanup runs in
finally blocks on success, error and cancellation. The bounded audit stores only
128 outcome enum values; no arguments, names, IDs or raw errors are recorded.
Permissions, credentials, tools and the eight-active-HTTP-request cap are
unchanged. At full saturation a cancellation HTTP request can receive 503;
individual local deadlines still expire. Shared bearer clients share authority;
this change does not claim separate client credentials or isolation.

Pause, resume and seek now receive an authorization callback. The real player
checks it immediately before issuing native commands, including inside the seek
diagnostics wrapper. Deferred handlers must call it after their last wait.
It checks scope lifetime, current tool permission and exact player ownership;
finished, replaced or detached players cannot receive late effects. Deferred
read-only results are also suppressed after cancellation or permission changes.
An already issued native command cannot be reversed, and read-only native work
may still finish after cancellation. No new write tool or automatic execution
was added.

The 27 new regressions exercise all three player commands across cancellation,
expiry, revocation, disable, detach, replacement and finished scope; actual HTTP
cancellation/deadline/shutdown; typed IDs and duplicate rejection; the unchanged
request cap; bounded redacted audit; and revoked deferred library responses.
The earlier 38-test focused integration run passed before the final duplicate
ping/shutdown-read guard refinements; the full gate below covers the final code.

## Verification

Fresh final ordered gate on this working tree:

- **280 Rust tests passed**, serial.
- Clippy all targets with warnings denied passed.
- Flutter analysis of lib and test passed with no issues.
- Native host build passed, including regenerated bridge.
- **461 Flutter tests passed**, **10 opt-in skips**.
- Whitespace checks passed.

New evidence includes a real local HTTP range read and HEAD exclusion under a
native trace; bounded/isolated/finished trace behaviour; a deliberately failing
synthetic NZB crossing the native bridge with a redacted selection-failure
snapshot; native event allowlisting; six repair lifecycle tests; cast RNG and
publisher helper checks. Fixtures contain synthetic bytes and no live content.
Earlier native/repair gate runs stopped on a type-complexity lint, two brace
infos and a nullable progress callback; corrected before that passing gate.
The final MCP ordered gate passed on its first run.

Logs: ignored `dist/audit/mcp-{rust,clippy,analyze,native,flutter}.log` for the
final ordered gate; earlier native/repair/publisher evidence is under
`dist/audit/reliability2-*`. No new installer, app signature,
physical playback/cast, clean-install result or GitHub CI run is claimed. Source
changes remain local and uncommitted. The prior independent platform-candidate
workflow is unchanged and has not been run remotely.

## External blockers

1. **MCP approval resolved:** the approved narrower change is applied above.
2. **Signing:** provide/provision the real publisher certificate and approved
   manifest trust root before integrating authenticated updates or claiming
   publisher identity. Hashes from the same release remain consistency evidence.
3. **Cessation/RAR4:** a sanitized reproducer or redistributable fixture is still
   missing. Do not change archive parsing on speculation or claim the report is
   fixed by instrumentation alone. Existing synthetic archive regressions pass.
4. **Devices and promotion:** clean-user/VM install/upgrade and real-device
   start/seek/resume/cast/accessibility checks remain external validation gates.
   Native host tests and synthetic fixtures do not substitute for them.

Backup-provider profiles, alternate-release recovery, readiness sampling,
watch-state/subtitle adapters and private sync remain feature proposals. They
are not silently added as fixes to reproduced faults. New spending, data-flow
or timestamp-transfer behaviour requires its own concrete contract and tests.
