# Mayu Client Runtime (`lib/mayu/client/src`)

This directory contains the browser-side runtime that:

- opens a server command stream,
- applies incoming command batches,
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
   - applies the `Initialize` + `SetListener` bootstrap batch,
   - decodes MessagePack command batches,
   - applies batches through `runtime.applyBatch(...)`,
   - on failure: reset session or reconnect with backoff.
3. `Runtime` in `runtime.ts`:
   - keeps an `id -> Node` map (`NodeSet`),
   - executes commands sequentially within each `Batch`,
   - supports DOM creation/update/remove, history, transfer, errors, etc.

## Module Map

- `main.ts`: minimal bootstrap and wiring.
- `mayu.ts`: browser API used by runtime and app (`callback`, `navigate`, `ping`, writer accessors).
- `session-connection.ts`: stream loop, batch decode/apply, reconnect/backoff.
- `session-recovery.ts`: reset policy (`shouldResetSession`) and full session reset (`resetSessionEntirely`).
- `view-transition.ts`: shared transition wrapper with fallback when View Transitions API is unavailable.
- `stream.ts`: HTTP stream connect logic + callback stream transport.
- `runtime.ts`: command dispatcher and DOM mutation engine.
- `protocol.ts`: shared `Command`, `Batch`, and command-error policy types.
- `client-event-codec.ts`: MessagePack encoding, framing, and optional
  per-event compression.
- `serializeEvent.ts`: serializes event/currentTarget/target payloads.
- `throttle.ts`: per-target callback throttling (~30 FPS).
- `transfer.ts`: in-memory session transfer blob between reconnects.
- `ping.ts`: updates `<mayu-ping>` status and RTT label.
- `constants.ts`: shared MIME types, endpoint path, ping interval.

## Data Paths

### Server -> Client (command stream)

- `SessionConnection.run` calls `initInputStream(endpoint, transferState)`.
- `connect(...)` validates:
  - HTTP success,
  - `content-type === application/vnd.mayu.event-stream`.
- Input stream is optionally decompressed based on `content-encoding`.
- `decodeMultiStream` yields batches directly. A batch is `Command[]`; a command
  is a compact `[name, ...arguments]` tuple.
- Each batch is applied with `runtime.applyBatch(...)`.
- There is no `Batch` command or extra transport wrapper. `ViewTransition`
  intentionally carries a nested batch as its argument.

### Client -> Server (callback stream)

- `window.Mayu.callback(event, id)` serializes and writes:
  - `["Callback", id, event, ping]`.
- `window.Mayu.navigate(href, pushState)` writes
  `["Navigate", href, pushState, ping]`.
- `window.Mayu.ping()` writes `["Ping", ping]` every `PING_INTERVAL`.
- writes made without a live callback transport are dropped and are never
  replayed after reconnect.
- Writes go through:
  - `TransformStream` -> `ClientEventEncoderStream` -> output writable.
- The encoder creates one frame per event:
  - one byte identifying raw MessagePack or `deflate-raw`,
  - four bytes containing the payload length,
  - one complete MessagePack event payload.
- Events of at least 512 bytes are independently compressed when doing so
  makes the frame smaller. Closing a compressor per event avoids buffering
  interactive events in the long-lived request.
- Output writable is:
  - streaming `PATCH` request when request streams are supported,
  - per-message fetch fallback otherwise; both send identical frame bytes.
- failures from either transport terminate the entire connection attempt so
  both stream directions reconnect together.

## Runtime/Command Behavior Notes

- `Batch` runs commands in order, awaiting async commands.
- Command failures are logged with their name and index within the batch. The default
  `COMMAND_ERROR_POLICY` continues the batch; strict mode throws.
- `ViewTransition` wraps a nested batch in `document.startViewTransition(...)` when available, and falls back to immediate apply when not available.
- `Transfer` stores transfer blob for reconnect handoff.
- `Pong` updates measured ping in `<mayu-ping>`.
- `RenderError` renders server-side exception UI.

## Reconnect and Recovery (Current)

In `SessionConnection.run(...)`:

- `failures` resets to `0` on successful connection.
- each loop iteration creates one `AbortController` for input/callback requests.
- On error:
  - if `shouldResetSession(error)` is true:
    - checks structured `error.code` first (e.g. `SESSION_EXPIRED`, `SESSION_CIPHER_ERROR`, `SESSION_NOT_FOUND`, `TOKEN_COOKIE_NOT_SET`),
    - falls back to normalized message matching (`"expired"`, `"cipher error"`, `"Session not found"`, `"Token cookie not set"`, and SCREAMING_SNAKE_CASE variants),
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

## Structured Stream Errors

Server stream errors now return JSON with:

- `code` (stable machine-readable error code),
- `message` (human-readable message),
- `error` (legacy field kept for backward compatibility).

Client parsing in `stream.ts` supports both new and legacy payload shapes.

## Client Tests

- test runner: Vitest (`jsdom` environment).
- config: `lib/mayu/client/vitest.config.ts`.
- test files:
  - `lib/mayu/client/src/session-recovery.test.ts`
  - `lib/mayu/client/src/session-connection.test.ts`
  - `lib/mayu/client/src/stream.test.ts`

Run:

- `npm run test --workspace lib/mayu/client`
- `npm run test:watch --workspace lib/mayu/client`

## Refactor Plan

1. Split `main.ts` into focused modules. (Done)
   - Extract `SessionConnection` (connect/decode/apply/retry loop).
   - Extract `SessionRecovery` (`shouldResetSession`, `resetSessionEntirely`).
   - Keep `Mayu` as a small client API surface (`callback`, `navigate`, `ping`).
2. Unify view-transition handling in a shared helper. (Done)
   - Use the same helper from both `session-recovery.ts` (full session reset morph) and `runtime.ts` (`ViewTransition` command).
3. Move from message matching to structured stream error codes. (Done)
   - Server returns `{ code, message }` and also keeps legacy `error`.
   - Client reset/retry policy checks `code` first, then falls back to messages.
4. Add explicit connection teardown/cancellation. (Done)
   - Each connection attempt now has an `AbortController`.
   - Teardown aborts stream requests and clears callback writer resources.
5. Isolate retry/backoff policy.
   - Extract backoff calculation so reconnect timing is easy to test and tune.
6. Tighten command typing.
   - Replace broad tuples/`any` with stronger command payload types so runtime dispatch is type-safe.
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
6. Step 6 (typing hardening).
7. Step 7 (logging cleanup).
