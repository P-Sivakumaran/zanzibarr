# Connection entry visibility — 2026-10-17

Baseline HEAD: `386c5e2c2f95f0edb6bf3b4537b3c39ebb92cca7`, branch
`kepler/fix-zanzibar-icon`, plus the previous uncommitted changes.

## Observed cause

The installed Windows app was confirmed at **1.12.0+13**. Its Search gear
opened indexer-only settings, which omitted the Integrations action. Full
Settings had a small puzzle-piece action, and the Codex login was below the
initial viewport. The running app was navigated to Integrations and scrolled
to its existing login button. The Codex path was populated and local MCP was
already enabled. No permission switches, credentials or account login were
changed during that inspection.

## Implemented in 1.13.0+14

- Label the Settings action **MCP & AI** and show it in full, indexer and
  provider settings.
- Add a **Sign in with ChatGPT** shortcut at the top of Integrations, using
  the existing managed Codex account flow. Show sign-in progress/errors there.
- Keep D-pad Up from the language selector directed to Back; Right from Back
  reaches MCP & AI.

Three new regression cases cover the Settings entry points. Existing
integration layout coverage now checks that sign-in is visible without
scrolling at 360 pixels and 200% text. The D-pad regression now identifies
Back specifically and checks access to MCP & AI. The initial full suite caught
the wider action changing geometric focus selection; the explicit focus route
corrects it.

## Verification

- Locked Rust tests: **266 passed**, serial execution.
- Locked Clippy (all targets, warnings denied): passed.
- Flutter analysis: no issues.
- Locked host native build: passed.
- Full Flutter suite: **300 passed, 8 existing screenshot skips**.
- Release inputs for v1.13 / 1.13.0+14: valid.
- Whitespace check: passed.

The final gate ran in repository order after the navigation correction.
The Windows release build passed in 96.6 seconds; Inno compilation completed
in 34.187 seconds. Executable ProductVersion is **1.13.0+14**. Setup/ZIP hashes,
ZIP CRCs and required native, CRT, license and MCP bridge components passed.
The dependency lockfile remained unchanged. Logs are under ignored
`dist/audit/connections-*`.

Artifacts (unsigned; not installed or published):

- `dist/windows/zanzibarr-windows-x64-setup.exe` — 29,295,336 bytes
- `dist/windows/zanzibarr-windows-x64.zip` — 38,267,724 bytes
- `dist/windows/SHA256SUMS`

SHA256:

```text
ca4fd6e73bcf2e6713d40af45de2fc875d538a19739d38a0fd1acb2f22816070  zanzibarr-windows-x64-setup.exe
b4fa1c01de03efb714b0fbdf4a9a608503b179e7f01d1e7b111ea270b47d7d30  zanzibarr-windows-x64.zip
```

## Scope

The installed 1.12 interface was inspected directly. The 1.13 interface is
covered by widget tests; a native 1.13 login/rendering check is still pending.
Live browser OAuth completion, actual recommendations, device playback and
clean-user installer lifecycle remain unverified. The running installation
was left open for the user to sign in. No commit, push, tag or publication
was performed.
