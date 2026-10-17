# Integrations verification — 2026-10-16

Baseline: 386c5e2c2f95f0edb6bf3b4537b3c39ebb92cca7 plus this task's existing
refinement/installer work and current integration changes. Branch:
kepler/fix-zanzibar-icon. No commit, push, tag, publication or new installation.

## Implemented

- Opt-in, bearer-authenticated loopback MCP endpoint, separate from casting and
  media streaming. Library/playback reads, optional indexer search and optional
  ready-player pause/resume/seek. Built-in outputs omit source URLs, paths and
  provider credentials. Permissions are checked on every call.
- Bounded Streamable HTTP client with JSON/SSE support, session negotiation,
  empty SSE priming support and explicit retry after session expiry. External
  endpoints and bearer credentials use OS secure storage. No automatic action
  retries, redirects or interactive remote OAuth.
- Explicit external tool discovery/calls and MCP metadata-provider plugins in
  the existing title lookup / structured search flow. Metadata plugins do not
  need or read the OMDb key and must preserve IMDb identity.
- Official Codex app-server managed browser sign-in, account status, cancellation
  and sign-out. Separate profile with keyring credential storage; no token files
  imported or tokens supplied to model APIs by Zanzibarr. Account management
  only; no embedded assistant chat UI.
- Claude Code/Desktop can use MCP with their own authentication. Claude.ai
  subscription login inside Zanzibarr is not offered under Anthropic's current
  third-party credential guidance.
- Optional Python stdio bridge, included in the Windows package. Python 3.10+
  must already be available to use it. Direct HTTP clients do not need Python.

Setup, exact provider contract, source links and limitations: [INTEGRATIONS.md](INTEGRATIONS.md).

## Verification

- Rust locked tests: 266 passed. Locked Clippy/all targets/warnings denied passed.
- Flutter analysis passed; host Rust build passed; full Flutter suite passed:
  287 tests, 8 existing opt-in screenshot skips. Flutter stages were rerun after
  the Dart-only recovery fixes; unchanged Rust suites were not repeatedly rerun.
- Nine focused protocol/account tests passed again with the strengthened empty
  SSE priming fixture. Three Python stdio bridge tests passed.
- Coverage includes loopback authentication/origin/path rejection, secure-storage
  failure recovery, permission changes, stale-player disposal, transport negotiation,
  session expiry, JSON/SSE responses, metadata identity, account RPC events,
  360px/200% text and plugin lookup without OMDb credentials.
- Full suite caught provider-form displacement and TV up-focus regressions from
  the original Settings entry placement. Moving the entry to an app-bar action
  restored both; existing settings/TV tests pass without changed expectations.
- Codex CLI 0.162.1: real initialize/account-read handshake passed in a new
  signed-out profile. No browser OAuth or inference requests were initiated.
- Windows release build and Inno Setup packaging passed at 1.11.0+12. Both
  SHA-256 hashes and ZIP CRC integrity passed; required native/CRT DLLs, notices,
  transparent Home asset and stdio bridge are present. All seven ICO frames
  were verified in the executable.
- Installer remains unsigned. Existing installed version remains 1.10.0+11.
  Clean-user installation/upgrade, rendered UI, live providers, actual OAuth
  completion, inference entitlement and physical playback/remote behavior are
  not certified. Other-platform builds were not run.

Artifacts are under ignored dist/windows/; logs and local harnesses are under
ignored dist/audit/. The complete Release directory is required for portable
execution; zanzibarr.exe alone is not a standalone app.

## SHA256SUMS

```text
784272d4011397c3163f3f62a02039c73c5395681399d0ac4b273873ca9682d7  zanzibarr-windows-x64-setup.exe
634b2ef5cc076a4c4a6aabae921e4c307b21554a7c88fc65954a1554c9a46f9a  zanzibarr-windows-x64.zip
```
