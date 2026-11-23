# Mayu Client Runtime (`lib/mayu/client/src`)

The browser side of a Mayu session. It:

- opens a stream of command batches from the server and applies them to the DOM,
- sends callbacks, navigations, visibility changes and pings back,
- reconnects, resumes a transferred session, or replaces a lost one.

## Layout

Each directory owns one concern. `main.ts` is the only file that knows about
all of them.

```
init.ts                  loads main.ts once the document is parsed
main.ts                  builds every module and wires them together
dispatch.ts              CommandDispatcher: batch → handler per command
protocol/
  commands.ts            the typed commands (server → browser) and handler types
  events.ts              the typed events (browser → server)
  constants.ts           MIME types, session path, intervals
  batch-codec.ts         reads the frames of the command stream
  event-codec.ts         encodes, frames and optionally compresses events
  msgpack.ts             the MessagePack subset the protocol uses
connection/
  session-connection.ts  the retry loop; holds the transfer state
  attempt.ts             one connection: both streams, until either ends
  backoff.ts             retry delays and attempt numbers
  command-stream.ts      GET (or POST with transfer state) → batches
  event-stream.ts        streaming PATCH, or one PATCH per event
  outbox.ts              the single way events leave the browser
  recovery.ts            which errors replace the session, and how
  stream-error.ts        StreamError and the server's error payload
dom/
  node-registry.ts       id ↔ node, and the listeners on each node
  hydrate.ts             binds server ids to existing or freshly parsed DOM
  children.ts            ReplaceChildren, <head> reordering, autofocus
  attributes.ts          attributes that need a property set as well
  handlers.ts            the DOM commands
  element-calls.ts       the element methods `ref.current` may call
features/
  callbacks.ts           DOM event → Callback; throttling; settlement
  navigation.ts          Navigation API interception; document navigation
  heartbeat.ts           pings, Pong, tab visibility
  inspect.ts             devtools queries (loaded with the devtools)
  browser-actions.ts     `browser.navigate`, `browser.alert`
  serialize-event.ts     what the server sees of an event
  settled.ts, throttle.ts
ui/
  status.ts              connection status, ping and progress on <mayu-ping>
  error-overlay.ts       RenderError / ReloadSucceeded
  render-error.ts        the overlay itself (loaded on the first error)
  view-transition.ts     startViewTransition with a fallback
  custom-elements/       <mayu-ping>, <mayu-exception>
devtools.ts              the devtools extension hook (loaded when present)
```

`features/test-client.ts` and `test-runtime.ts` are test support. They wire
modules the way `main.ts` does so a test can drive them through one object.

## How a command gets handled

1. `connection/attempt.ts` reads a batch from the command stream. Each batch
   is a frame: four bytes of payload length, then the batch as MessagePack.
   A stream that ends inside a frame fails the attempt.
2. `CommandDispatcher.applyBatch` walks it in order and calls the handler
   registered for each command, waiting for handlers that return a promise.
3. The handler lives in the module that owns the command:

   | Commands                                                       | Module                                              |
   | -------------------------------------------------------------- | --------------------------------------------------- |
   | `Initialize`, `CreateTree`, `ReplaceChildren`, `Set*`, …       | `dom/handlers.ts`                                   |
   | `CallbackComplete`, `CallbackFailed`                           | `features/callbacks.ts`                             |
   | `NavigationComplete`, `NavigationFailed`, `DocumentNavigation` | `features/navigation.ts`                            |
   | `Pong`                                                         | `features/heartbeat.ts`                             |
   | `BrowserAction`                                                | `features/browser-actions.ts`                       |
   | `InspectResult`                                                | `features/inspect.ts`                               |
   | `RenderError`, `ReloadSucceeded`                               | `ui/error-overlay.ts`                               |
   | `Transfer`                                                     | `connection/session-connection.ts`                  |
   | `ViewTransition`                                               | `dispatch.ts` (it carries a batch)                  |
   | `TransferFailed`                                               | `connection/session-connection.ts`, before dispatch |

`main.ts` merges these into one table typed as
`CommandHandlers<DispatchedCommandName>`, so a command without a handler, or a
handler with the wrong arguments, does not compile.

A failed command is logged with its name and index, and the rest of the batch
is applied (`COMMAND_ERROR_POLICY` in `dispatch.ts`; tests use `"throw"`).

## How an event gets sent

1. A feature calls `outbox.send([name, ...arguments])`, for example
   `callbacks.dispatch` from a DOM listener that `dom/node-registry.ts`
   installed.
2. The outbox puts the header in: `[name, ping, telemetry, ...arguments]`.
   `ping` is `performance.now()`, which the server echoes in a `Pong`.
   `telemetry` is `null`, or the time spent applying commands since the
   last event.
3. `protocol/event-codec.ts` frames it: one byte for raw MessagePack or
   `deflate-raw`, four bytes of payload length, then the payload. Events of 512
   bytes or more are compressed when that makes the frame smaller.
4. `connection/event-stream.ts` sends the frame in a streaming `PATCH`, or in
   a `PATCH` of its own where request streams are unsupported.

With no connection, `send` resolves to `false` and the event is dropped.
Events are never replayed. Features that wait for an answer subscribe to
`outbox.onDisconnect` and reject what they were waiting for.

The events, without their header:

- `["Callback", listenerId, event]` for continuous events (input,
  pointermove, scroll, …), at most 30 a second per listener, and
  `["Callback", listenerId, event, settleId]` for the rest, answered by
  `CallbackComplete` or `CallbackFailed`.
- `["Navigate", id, href]` for an intercepted same-origin navigation, which
  stays pending until `NavigationComplete(id)`.
- `["Ping"]` after `PING_INTERVAL` without outbound traffic. The timer runs
  in a worker where possible, because hidden tabs throttle page timers
  beyond the server's session timeout.
- `["Visibility", hidden]` on `visibilitychange`, and on connecting from a
  hidden tab.
- `["Inspect", id, query]` from the devtools.

## Connecting and recovering

`SessionConnection.run` loops forever:

1. `runAttempt` opens the command stream (`GET`, or `POST` with the transfer
   state), attaches a writer to the outbox, opens the event stream, and applies
   batches. It resolves when the command stream ends cleanly and rejects when
   either stream fails. Either way it aborts both requests and detaches the
   outbox, so both directions always reconnect together.
2. After a clean end the loop reconnects at once, then a second later each
   time the server keeps closing new streams.
3. After a failure it checks the error code. For `SESSION_NOT_FOUND`,
   `SESSION_EXPIRED`, `SESSION_CIPHER_ERROR`, `SESSION_RESTORE_FAILED`,
   `TOKEN_COOKIE_NOT_SET` and `TRANSFER_FAILED` it fetches the page again,
   morphs the document into it (`morphdom`, loaded on demand) and connects to
   the new session. Otherwise, or if that fails, it waits one second more per
   failure in a row, up to ten.

A `Transfer` command hands the browser the encrypted session of a server that
is stopping. The connection keeps it until another server has resumed it, and
reports "transferring" rather than "disconnected" meanwhile.

## Keeping it small

Every page loads `init` and `main`. Anything a healthy production session
does not need on every page is a separate chunk behind `import()`: the error
overlay, both custom elements, `morphdom`, and the devtools with
`features/inspect.ts`.

`protocol/msgpack.ts` is a codec for the part of MessagePack the protocol
uses, in place of a general-purpose library that was two fifths of the
bundle. `@msgpack/msgpack` remains a dev dependency: `msgpack.test.ts`
compares the two on random values, and decodes bytes packed by Ruby.

`npm run size` builds and prints every chunk, and fails when the eager chunks
outgrow the budget in `scripts/check-size.js`. Lower the budget when a change
shrinks them.

## The protocol, defined once

`../protocol.json` lists the commands, events, error codes, continuous event
types and element methods. `protocol-manifest.test.ts` checks this runtime
against it, and `lib/mayu/protocol.test.rb` checks the server.

## Tests

Vitest with jsdom; tests sit next to the module they cover.

- `npm test -w gems/mayu-live/lib/mayu/client` runs the tests and the size check.
- `npm run typecheck -w gems/mayu-live/lib/mayu/client`
