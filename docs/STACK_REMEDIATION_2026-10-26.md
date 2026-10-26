# Stack remediation: implementation and acceptance ledger

26 October 2026. Implements the [critical stack review](TECH_STACK_REVIEW_2026-10-26.md) against base `d8f4ac05e72db7df9cfcd97e1c39c97363c14b1f` plus the preserved working tree. This file distinguishes corrections, architectural decisions and remaining delivery gates. No installer, signing identity, clean-user/device result or published release is implied.

## Implemented corrections

| Review area | Implemented behavior | Verification / limit |
| --- | --- | --- |
| Native Android provenance | A source-controlled manifest pins all four existing media JAR sizes and SHA-256 values. Gradle checks new and cached files, downloads through temporary files with size/time limits, rejects unknown JARs and runs before compilation. | Downloaded all four and matched pins. Pins are a reviewed baseline from release digests, not an independent publisher signature. Gradle execution still requires the Android build environment. |
| Android native compatibility | APK auditor checks every native ELF and 16 KiB ZIP alignment where required; reports retain exact hashes. | Eight ELF libraries in the pinned JARs passed alignment. Rust/Flutter/libc++ and APK/runtime compatibility must pass final CI/device gates. 16 KiB requirements apply to 64-bit native libraries; 32-bit details remain visible in reports. |
| HTTP admission | At most 32 active tasks per listener, 10-second header deadline and 60-second socket-write stall limit. Completed tasks are reaped; shutdown aborts and drains children. | Tests cover idle unauthorized headers, overload, stalled writes, slow upstream exclusion, existing range/token handling and shutdown. Long legitimate streams have no short total runtime deadline. |
| Cache residency | Decoded caches retain existing FIFO/segment-count behavior plus a 32 MiB per-cache byte cap and shared 256 MiB cache-residency reservation budget. | Tests cover variable segment sizes, oversize bypass, shared reservations, eviction and release. Active readers can retain Arc clones after eviction; this is not a total process/decoder memory guarantee. Skipped caching never fails a requested fetch. |
| Credential durability | Provider settings use one validated versioned secure record, serialized across stores and read-verified before legacy-key cleanup. | Failed saves preserve the old complete record; legacy load compatibility, concurrent access, corruption and cleanup failure are tested. An empty authoritative record prevents clear from resurrecting old credentials. Failed explicit credential cleanup is reported. |
| Playback lifecycle | NativePlaybackSession owns pending/active native IDs, request ordering, adoption, release and idempotent closure. Player disposal revokes native ownership before visual/preferences drains. | Late completion/error, overlapping preparation, stale release and blocked-stop/newer-request regressions. Native ownership is extracted; the complete media/cast/UI orchestration has not been rewritten. |
| Library durability/privacy | History/watchlist use a shared repository seam with bounded versioned secure snapshots, verified writes, last-good recovery, preservation of damaged records and visible unrecoverable errors. Unsupported future schemas cannot be downgraded from backup. | Recovery, failed writes, unsupported schemas and explicit-deletion cleanup regressions. Successful history removal/untracking purges retained snapshots so deleted titles cannot reappear. Existing UI retry/error behavior handles storage failures. |
| Edition composition | Explicit Legacy/Restricted catalogue route modules replace source-text edits to main/settings navigation. Clean import allowlist and source/bundle audits remain. | Both current source profiles prepare successfully; existing preparation regressions pass. Previously built edition installers do not contain these new changes. |
| Update trust | The Windows install path now checks Authenticode against source-controlled publisher pins after checksum verification and before launch. No pins are fabricated. With no provisioned publisher, the ordinary UI offers the release page rather than an automatic install. | Correct-checksum/untrusted-publisher rejection regression. Real certificate verification and signed manifest/rollback/key rotation remain release gates; hashes alone are not described as publisher authentication. |
| Build inputs | Actions references are pinned to upstream commit SHAs, CI Rust is 1.99.0, Android NDK is 28.2.13676358 and libc++ copy validates that exact NDK. Missing runtime libraries fail instead of logging and continuing. | actionlint; toolchain contract documented. Runner OS images and system packages remain serviced inputs whose resolved versions need recording. |
| Release independence | Manual Legacy release preparation can select one platform, retains shared verification and resolves a single source SHA. Strict asset preparation creates checksums/source metadata and publishes only an explicit selected list to a draft. | Windows-only, missing-artifact and safe Android extraction fixtures. This creates drafts, not automatic public promotion or signed releases. |
| Ongoing maintenance | Dependabot tracks Actions, Cargo and Pub; a scheduled/read-only advisory workflow scans both Rust lockfiles with pinned cargo-audit. Build jobs execute dependency/artifact inventory and retain audit artifacts separately from installable packages. | Actual local advisory results and final gates recorded below. Inventory is not a signed attestation, complete native licence inventory or vulnerability-free guarantee. |
| Android privacy | Explicit cloud/device-transfer backup exclusions prevent deliberate export of app-private state and undecryptable key restoration. | Source XML checked; merged manifest and OEM transfer/device behavior remain platform acceptance work. |
| Malformed inputs | Added deterministic generated NZB/yEnc/volume-name stress cases and extreme numeric inputs alongside existing archive/range/cancellation fixtures. | This is regression stress coverage, not a completed coverage-guided fuzzing campaign or a reproduced RAR4 fix. |

## Dependency advisories discovered during implementation

The original stack evaluation did not run a vulnerability scan. This implementation installed cargo-audit 0.22.2 into ignored `dist/tools/` and scanned both lockfiles. Both initially reported six vulnerability advisories covering rustls, rustls-webpki and webpki-roots. Additional warnings covered anyhow/Tokio unsoundness, a yanked futures-util and an unmaintained adler dependency in a target-specific backtrace chain.

Targeted compatible updates: rustls 0.23.46, rustls-webpki 0.103.16, webpki-roots 1.0.10, Tokio 1.53.3, anyhow 1.0.103, futures-util 0.3.32; engine backtrace 0.3.76 replaces the old adler chain. Their required transitive lockfile changes are retained. No FRB/media package upgrade or generated bridge signature change was required.

Both final scans returned **zero reported vulnerabilities and zero warnings**. This is an advisory-database result, not proof of universal exploitability before the fix or absence of undiscovered defects afterward. For example, the rustls Brotli allocation advisory applies only when its optional Brotli feature is enabled. [Rustls advisory](https://rustsec.org/advisories/RUSTSEC-2026-0348.html), [certificate verification advisory](https://rustsec.org/advisories/RUSTSEC-2026-0382.html), [root-store advisory](https://rustsec.org/advisories/RUSTSEC-2026-0381.html), [Tokio advisory](https://rustsec.org/advisories/RUSTSEC-2026-0386.html).

## Architectural decisions

- Keep Flutter/Rust/FRB/libmpv. No demonstrated limitation justifies a framework rewrite.
- Keep the outbound Rust HTTP client for this change. The prior URL/DNS/redirect hardening remains covered, and replacing it without preserving those policies would introduce a new risk. A maintained-client comparison should use the same policy and test corpus; no throughput improvement is claimed without measurements.
- Keep private library data in existing secure storage while introducing a repository seam and recovery. A wholesale SQLite migration is not justified by the current bounded history size. If cross-record transactions, larger catalogues or sync are implemented, evaluate a maintained encrypted database with key recovery and migration tests through this seam. The snapshot implementation does not claim database transactions.
- Keep existing hardware-decoder choices; corrected the rationale to acknowledge current mpv documentation treats auto and auto-safe as aliases. Active decoding still needs validation on the shipped binary/device.
- Do not invent signing keys, assert trusted Clean media from filenames, or transfer timestamps between different cuts. Those require their real trust/content contracts.

## Standards review

One actionable finding: the new native session owner originally allocated request identity after asynchronous cleanup. A blocked old stop could allow an obsolete request to supersede a newer one. Fixed by reserving identity before cleanup and checking it afterward; a blocked-stop regression passes. The re-review reported no remaining actionable Standards findings in its reviewed scope. A subsequent stale-error regression also passes.

## Specification review

Two actionable findings: explicit removal initially retained titles in last-good recovery data, and Android audit reports were generated but not uploaded. Deletion-aware writes now purge retained snapshots after verifying the new primary. Platform workflows execute the inventory tool and retain separate audit artifacts. Broader engineering and device acceptance items remain listed below; no full-plan certification is claimed.

Review summary: Standards 1 finding, corrected; Specification 2 findings, corrected. No remaining confirmed defects from those reviews are being presented as fixed merely because tests pass.

## Verification


Final ordered gate passed after the dependency updates: **290 Rust tests**, Clippy with warnings denied, Flutter analysis, native host build, **552 Flutter tests with 10 opt-in skips**, and whitespace. A final Dart-only stale-error correction was followed by fresh analysis and the complete **553-test Flutter suite**, also passing with 10 skips. The CLI passed `cargo check --locked --manifest-path tools/zanzibarr-cli/Cargo.toml --all-targets` using the updated lockfile.

Ten edition-preparation, four native-audit and four release-asset tests passed (18 tooling regressions), alongside actionlint and backup/extraction XML checks. Both final edition source profiles prepare successfully under `dist/editions/{clean,restricted}-remediation-02`; these are source snapshots, not newly built installers.

All four downloaded native JARs matched pinned SHA-256/size values; the eight ELF libraries passed alignment inspection. Both final cargo-audit scans returned zero vulnerabilities and zero warnings. Scanner coverage is Rust lockfiles, not all native binaries or Dart dependencies.

Results are recorded in `dist/audit/stack-remediation/`, including `gate-results.json`, `final-dart-results.json`, final advisory JSON, CLI check and native audit reports. Earlier gate attempts stopped on leftover session setters, brace-style issues and intermediate tests while interfaces were changing; they are not represented as passing final evidence. No claim is made that the installed application uses the updated dependencies.

## Remaining acceptance work and prerequisites

1. Provision the real publisher identity and independently trusted signed update manifest, including edition/platform binding, monotonic rollback policy, expiry and key rotation. Authenticode enforcement is implemented; signed-manifest/channel engineering remains unfinished. Automatic Windows installation remains unavailable without trust configuration.
2. Execute clean-user install/co-install/upgrade, actual Windows authentication/relock, real playback/seek/resume/cast and TV/accessibility checks. Establish measured startup/seek/rebuffer/frame/cache/disk baselines before tuning prefetch or making speed claims.
3. Complete the trusted Clean catalogue/media-provenance contract. Clean remains empty/closed. No automated metadata filter can certify arbitrary NZB bytes.
4. Complete native codec/source/licence provenance and servicing for each platform, including the Homebrew-derived macOS payload. The dependency/artifact inventory explicitly records that this is incomplete.
5. Obtain a sanitized cessation/RAR4 reproducer and continue coverage-guided parser/archive fuzzing in an appropriate environment. Generated malformed-input tests and synthetic archive fixtures do not close those reports.
6. Further extraction of player/cast/recovery orchestration can proceed incrementally through the native-session/repository seams. This is remaining maintainability work, not a claimed completed rewrite or a reason to discard passing behavior.

The installed app and current playback were preserved. No commit, push, tag, installer execution, signing or publication was performed.
