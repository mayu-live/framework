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
   - creates `Mayu` API instance and stores it on `window.Mayu`,
   - creates `SessionConnection`,
   - starts session connection loop at `/.mayu/session/:sessionId`.
2. `SessionConnection.run()` loop:
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

- `main.ts`: minimal bootstrap and wiring.
- `mayu.ts`: browser API used by runtime and app (`callback`, `navigate`, `ping`, writer accessors).
- `session-connection.ts`: stream loop, patch decode/apply, reconnect/backoff.
- `session-recovery.ts`: reset policy (`shouldResetSession`) and full session reset (`resetSessionEntirely`).
- `view-transition.ts`: shared transition wrapper with fallback when View Transitions API is unavailable.
- `stream.ts`: HTTP stream connect logic + callback stream transport.
- `runtime.ts`: patch dispatcher and DOM mutation engine.
- `serializeEvent.ts`: serializes event/currentTarget/target payloads.
- `throttle.ts`: per-target callback throttling (~30 FPS).
- `transfer.ts`: in-memory session transfer blob between reconnects.
- `ping.ts`: updates `<mayu-ping>` status and RTT label.
- `constants.ts`: shared MIME types, endpoint path, ping interval.

## Data Paths

### Server -> Client (patch stream)

- `SessionConnection.run` calls `initInputStream(endpoint, transferState)`.
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

In `SessionConnection.run(...)`:

- `failures` resets to `0` on successful connection.
- each loop iteration creates one `AbortController` for input/callback requests.
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
- at iteration teardown (`finally`):
  - abort active requests/streams,
  - abort/release callback writer,
  - clear `window.Mayu` writer reference.

## Better Long-Term Error Contract (Server + Client)

String matching is fragile. A safer protocol is to return structured stream errors, e.g.:

- `code: "SESSION_EXPIRED"`
- `code: "SESSION_NOT_FOUND"`
- `code: "TOKEN_COOKIE_MISSING"`
- `code: "CIPHER_ERROR"`

Then client policy can branch on `code` instead of free-form messages.

## Client Tests

- test runner: Vitest (`jsdom` environment).
- config: `lib/mayu/client/vitest.config.ts`.
- test files:
  - `lib/mayu/client/src/session-recovery.test.ts`
  - `lib/mayu/client/src/session-connection.test.ts`

Run:

- `npm run test --workspace lib/mayu/client`
- `npm run test:watch --workspace lib/mayu/client`

## Refactor Plan

1. Split `main.ts` into focused modules. (Done)
   - Extract `SessionConnection` (connect/decode/apply/retry loop).
   - Extract `SessionRecovery` (`shouldResetSession`, `resetSessionEntirely`).
   - Keep `Mayu` as a small client API surface (`callback`, `navigate`, `ping`).
2. Unify view-transition handling in a shared helper. (Done)
   - Use the same helper from both `session-recovery.ts` (full session reset morph) and `runtime.ts` (`ViewTransition` patch).
3. Move from message matching to structured stream error codes.
   - Return `{code, message}` from server-side stream errors.
   - Branch on `code` in client reset/retry policy.
4. Add explicit connection teardown/cancellation. (Done)
   - Each connection attempt now has an `AbortController`.
   - Teardown aborts stream requests and clears callback writer resources.
5. Isolate retry/backoff policy.
   - Extract backoff calculation so reconnect timing is easy to test and tune.
6. Tighten patch typing.
   - Replace broad tuples/`any` with stronger patch payload types so runtime patch dispatch is type-safe.
7. Gate debug logging.
   - Route noisy `console.*` calls through a debug logger flag to keep production output clean.
8. Add targeted tests for critical recovery behavior. (Done)
   - `shouldResetSession` cases.
   - missing `x-mayu-session-id` during reset.
   - reset failure falls back to reconnect backoff.

### Suggested Order

1. Step 1 (split responsibilities).
2. Step 2 (shared view transition helper).
3. Step 5 (retry policy extraction).
4. Step 4 (connection teardown model).
5. Step 8 (tests around current behavior).
6. Step 3 (structured error contract, requires server/client changes).
7. Step 6 (typing hardening).
8. Step 7 (logging cleanup).
