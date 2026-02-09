# Mayu Client Runtime (`lib/mayu/client/src`)

This directory contains the browser-side runtime that:

- opens a server patch stream,
- applies incoming DOM patches,
- sends user callbacks/navigation/ping events back to the server,
- reconnects and restores state when possible.

## High-Level Flow

1. `init(sessionId)` in `main.ts`:
   - installs a default view-transition stylesheet,
   - creates `Runtime`,
   - creates `window.Mayu` API instance,
   - starts patch streaming at `/.mayu/session/:sessionId`.
2. `startPatchStream(runtime, endpoint)` loop:
   - opens input stream (`GET` or `POST` with transfer state),
   - opens callback output stream (`PATCH`),
   - decodes MessagePack patch batches,
   - applies patches through `runtime.apply(...)`,
   - on failure: reset session or reconnect with backoff.
3. `Runtime` in `runtime.ts`:
   - keeps an `id -> Node` map (`NodeSet`),
   - executes patches sequentially (`Batch`),
   - supports DOM creation/update/remove, history, transfer, errors, etc.

## Module Map

- `main.ts`: bootstrap + stream lifecycle + recovery policy.
- `stream.ts`: HTTP stream connect logic + callback stream transport.
- `runtime.ts`: patch dispatcher and DOM mutation engine.
- `serializeEvent.ts`: serializes event/currentTarget/target payloads.
- `throttle.ts`: per-target callback throttling (~30 FPS).
- `transfer.ts`: in-memory session transfer blob between reconnects.
- `ping.ts`: updates `<mayu-ping>` status and RTT label.
- `constants.ts`: shared MIME types, endpoint path, ping interval.

## Data Paths

### Server -> Client (patch stream)

- `startPatchStream` calls `initInputStream(endpoint, transferState)`.
- `connect(...)` validates:
  - HTTP success,
  - `content-type === application/vnd.mayu.event-stream`.
- Input stream is optionally decompressed based on `content-encoding`.
- `decodeMultiStream` yields patch batches.
- Each batch is applied with `runtime.apply(...)`.

### Client -> Server (callback stream)

- `window.Mayu.callback(event, id)` serializes and writes:
  - `{type: "callback", payload: {id, event}, ping}`.
- `window.Mayu.navigate(href, pushState)` writes navigation message.
- `window.Mayu.ping()` writes heartbeat every `PING_INTERVAL`.
- Writes go through:
  - `TransformStream` -> `JSONEncoderStream` -> `TextEncoderStream` -> output writable.
- Output writable is:
  - streaming `PATCH` request when request streams are supported,
  - per-message fetch fallback otherwise.

## Runtime/Patch Behavior Notes

- `Batch` runs patches in order, awaiting async patches.
- `ViewTransition` patch wraps a nested patch list in `document.startViewTransition(...)` when available, and falls back to immediate apply when not available.
- `Transfer` patch stores transfer blob for reconnect handoff.
- `Pong` updates measured ping in `<mayu-ping>`.
- `RenderError` renders server-side exception UI.

## Reconnect and Recovery (Current)

In `startPatchStream(...)`:

- `failures` resets to `0` on successful connection.
- On error:
  - if `shouldResetSession(error)` is true for:
    - `"expired"`
    - `"cipher error"`
    - `"Session not found"`
    - `"Token cookie not set"`
    - call `resetSessionEntirely()`,
    - fetch full HTML page + `x-mayu-session-id`,
    - morph DOM with `morphdom`,
    - clear transfer state,
    - continue with new endpoint,
    - if reset fails, log the reset failure and continue with normal backoff/retry.
  - otherwise:
    - wait with linear backoff (`1s .. 10s`),
    - retry same endpoint.

## Better Long-Term Error Contract (Server + Client)

String matching is fragile. A safer protocol is to return structured stream errors, e.g.:

- `code: "SESSION_EXPIRED"`
- `code: "SESSION_NOT_FOUND"`
- `code: "TOKEN_COOKIE_MISSING"`
- `code: "CIPHER_ERROR"`

Then client policy can branch on `code` instead of free-form messages.

## Small Refactor Opportunities

- Split `main.ts` responsibilities:
  - `SessionConnection` (stream/connect/retry),
  - `SessionRecovery` (reset/morphdom/new endpoint),
  - `MayuAPI` (callback/navigate/ping writer).
- Make retry strategy injectable/testable.
- Keep one helper for view transitions used both in runtime patches and full-session reset.
