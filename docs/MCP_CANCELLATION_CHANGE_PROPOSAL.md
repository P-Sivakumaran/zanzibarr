# MCP cancellation hardening - approved and implemented

Automatic approval review rejected applying the first patch because it changed
the MCP security boundary and concurrency without sufficiently explicit
permission. No rejected code was applied. This narrower proposal retains all
existing access defaults, bearer credentials and the eight-request limit.

## Exact intended changes

- Add an in-memory call context with a 30-second timer, cancelled/finished state,
  an awaited cancellation signal and `check()` that rejects an expired call.
- Scope active request IDs to the existing authenticated bearer client. Handle
  `notifications/cancelled` only for an existing request in that scope; initialize
  is never cancellable. Unknown/malformed notifications remain harmless.
- Cancel all active contexts on endpoint shutdown and token/configuration change.
  Reject duplicate active request IDs. Remove context/timers in finally blocks.
- Change the internal tool callback to receive the context. A timeout stops
  waiting and marks the context cancelled; it does not claim to forcibly abort
  a remote operation or reverse an already executed native player command.
- Pass an authorization callback into the existing pause/resume/seek handlers.
  Deferred handlers must invoke it after their final wait and immediately before
  an effect. It checks the live permission switches, playback ownership and call
  expiry; a stale or disabled grant cannot perform a later effect.
- Keep tool discovery separate from execution permission. Add no play-new-media,
  download, export, filesystem, LAN, arbitrary-execution or external-write tool.
- Keep a bounded in-memory outcome audit with fixed enum-like labels only. No
  tool arguments, metadata, source URLs, credentials, tokens or raw failures.
- Update existing integration tests for callback signatures and add deterministic
  cancellation/deadline/revocation tests where a deferred callback is released
  after cancellation and must perform zero effects.

Files: lib/integrations/mcp_call_context.dart (new), mcp_transport.dart,
integration_runtime.dart, lib/player/player_screen.dart, and integration tests.
No settings migration, new persistent client credential, concurrency increase or
release publication is part of this narrower change. Separate per-client tokens
would require a later concrete settings/UI proposal; shared-bearer clients have
shared authority until then.

## Acceptance checks before delivery

1. A deferred player callback rechecks authorization and cannot act after call
   cancellation, expiry, permission revocation, endpoint close or player detach.
2. Unknown cancellation and completed requests do not affect another active ID.
3. Scope timers and active maps are cleaned on success/error/close.
4. Existing loopback/Host/Origin/authentication/body bounds remain intact.
5. Focused MCP regressions and the full ordered application gate pass.

The user approved this narrower proposal with "continue". It is now applied;
verification evidence is recorded in the reliability follow-up. The original
rejection is retained above as history, not a current approval blocker.

The eight-request cap also applies to cancellation HTTP requests; at saturation
a cancellation can receive 503, while each active call still expires locally.
Shared bearer clients retain shared authority; separate per-client credentials
were not introduced.
