# Mayu Client Runtime (`lib/mayu/client/src`)

The browser side of a Mayu session. It:

- opens a stream of command batches from the server and applies them to the DOM,
- sends callbacks, navigations, visibility changes and pings back,
- reconnects, resumes a transferred session, or replaces a lost one.

## Layout

Each directory owns one concern. `main.ts` is the only file that knows about
all of them.

```
init.ts                  asks for the command stream, loads main.ts once the document is parsed
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
  supports-request-streams.ts  whether fetch can stream a request body
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
  resync.ts              asks for the page when a command can't be applied
  browser-actions.ts     `browser.navigate`, `browser.alert`
  serialize-event.ts     what the server sees of an event
  settled.ts, throttle.ts
ui/
  status.ts              connection status, ping and progress on <mayu-ping>
  error-overlay.ts       RenderError / ReloadSucceeded
  render-error.ts        shows an error (loaded on the first one)
  error-report.ts        works an error out for display
  error-console.ts       draws the report in the console
  view-transition.ts     startViewTransition with a fallback
  h.ts                   creates an element with children and attributes
  morph-document.ts      morphs the document into another page's HTML
  custom-elements/       one .html and one .ts per element, see below
devtools.ts              the devtools extension hook (loaded when present)
```

`features/test-client.ts` and `test-runtime.ts` are test support. They wire
modules the way `main.ts` does so a test can drive them through one object.

## How a command gets handled

1. `connection/attempt.ts` reads a batch from the command stream. Each batch
   is a frame: four bytes of payload length, then `[seq, commands]` as
   MessagePack. `seq` counts the batches of the session. A stream that ends
   inside a frame fails the attempt.
2. `CommandDispatcher.applyBatch` walks it in order and calls the handler
   registered for each command, waiting for handlers that return a promise.
3. The handler lives in the module that owns the command:

   | Commands                                                           | Module                                              |
   | ------------------------------------------------------------------ | --------------------------------------------------- |
   | `Initialize`, `Resync`, `CreateTree`, `ReplaceChildren`, `Set*`, … | `dom/handlers.ts`                                   |
   | `CallbackComplete`, `CallbackFailed`                               | `features/callbacks.ts`                             |
   | `NavigationComplete`, `NavigationFailed`, `DocumentNavigation`     | `features/navigation.ts`                            |
   | `Pong`                                                             | `features/heartbeat.ts`                             |
   | `BrowserAction`                                                    | `features/browser-actions.ts`                       |
   | `InspectResult`                                                    | `features/inspect.ts`                               |
   | `RenderError`, `ReloadSucceeded`                                   | `ui/error-overlay.ts`                               |
   | `Transfer`                                                         | `connection/session-connection.ts`                  |
   | `ViewTransition`                                                   | `dispatch.ts` (it carries a batch)                  |
   | `TransferFailed`                                                   | `connection/session-connection.ts`, before dispatch |

`main.ts` merges these into one table typed as
`CommandHandlers<DispatchedCommandName>`, so a command without a handler, or a
handler with the wrong arguments, does not compile.

A failed command is logged with its name and index, and the rest of the batch
is applied (`COMMAND_ERROR_POLICY` in `dispatch.ts`; tests use `"throw"`).

## When the page and the server disagree

A DOM command fails when the page is not what the server thinks it is: a
node it names is not there, or the ids it sent don't line up with the
document. `main.ts` then loads `features/resync.ts`, which sends a `Resync`
event with the reason. The server answers with a `Resync` command: the whole
page as its vnode tree has it now, and the ids of its nodes.
`dom/handlers.ts` morphs the document into that page, so nodes the two share
keep their focus and scroll position, and binds the ids again. A form field
keeps what the user entered unless the server's page has another default for
it than the page had. The session and its component state are untouched.

One request is in flight at a time. If the page still differs within five
seconds of a resync, the difference is one the server can't repair, such as
markup the browser corrects while parsing. It is logged once, and the page
asks for no more resyncs.

## Custom elements

The runtime draws its own UI in custom elements, so the page's styles can't
reach it and it can't disturb the page.

- `<mayu-ping>` is the status badge in the corner. The server renders one at
  the end of every body. `ui/status.ts` sets its attributes, which works
  before the element has loaded.
- `<mayu-navigation-progress>` and `<mayu-connection-dialog>` live in the
  shadow root of `<mayu-ping>`, which passes its attributes on to them.
- `<mayu-exception>` is the error overlay. `ui/render-error.ts` gives it an
  `ErrorReport` and adds it to the body.

Each element is two files in `ui/custom-elements/`: `name.html` holds the
markup and the styles, `name.ts` the behaviour. `shadow.ts` connects them:
`shadowTemplate(html)` parses the HTML once and fills an element's shadow
root with it, and `part(root, id)` returns the element with that id, or
throws when the template has none. An element fills its shadow root in a
field initialiser, so its parts exist from the start. What can only happen
in the document, such as opening a dialog, waits for `connectedCallback`.

## How an event gets sent

1. A feature calls `outbox.send([name, ...arguments])`, for example
   `callbacks.dispatch` from a DOM listener that `dom/node-registry.ts`
   installed.
2. The outbox puts the header in:
   `[name, ping, ack, telemetry, ...arguments]`. `ping` is
   `performance.now()`, which the server echoes in a `Pong`. `ack` is `null`,
   or the `seq` of the last batch the page applied. `telemetry` is `null`, or
   the time spent applying commands since the last event.
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
- `["Resync", reason]` when a DOM command could not be applied.

## Connecting and recovering

`SessionConnection.run` loops forever:

1. `runAttempt` opens the command stream, attaches a writer to the outbox,
   opens the event stream, and applies batches. It resolves when the command
   stream ends cleanly and rejects when either stream fails. Either way it
   aborts both requests and detaches the outbox, so both directions always
   reconnect together. It returns once the batch it was applying is done,
   and applies no batch after that.
2. After a clean end the loop reconnects at once, then a second later each
   time the server keeps closing new streams.
3. After a failure it checks the error code. For `SESSION_NOT_FOUND`,
   `SESSION_EXPIRED`, `SESSION_CIPHER_ERROR`, `SESSION_RESTORE_FAILED`,
   `TOKEN_COOKIE_NOT_SET` and `TRANSFER_FAILED` it fetches the page again,
   morphs the document into it (`morphdom`, loaded on demand) and connects to
   the new session. Otherwise, or if that fails, it waits one second more per
   failure in a row, up to ten.

What the stream starts with depends on what the page can tell the server:

- The first connection is a plain `GET`. The page is fresh from the HTML
  response, so the server sends `Initialize` with the ids of its nodes.
- A reconnect sends `mayu-last-batch: <seq>`, the last batch the page
  applied. The server keeps the batches the page has not acknowledged, and
  sends the ones after `seq`. The page keeps its nodes and listeners, and
  nothing is lost with the old stream.
- If the server no longer has those batches, the stream starts with
  `Resync` and the page is morphed into the server's. The same happens when
  a reconnect names no batch although the server sent some, and after a
  batch the page could not decode, when it sends `mayu-last-batch: -1`
  rather than be sent that batch again.
- With a transfer state the request is a `POST` that names no batch. The
  server that resumes the session starts counting from one and sends
  `Initialize`.

A second stream for a session takes over from the first: the server closes
the old one rather than refusing the new one.

A `Transfer` command hands the browser the encrypted session of a server that
is stopping. The connection keeps it until another server has resumed it, and
reports "transferring" rather than "disconnected" meanwhile.

## Keeping it small

Every page loads `init` and `main`. Anything a healthy production session
does not need on every page is a separate chunk behind `import()`: the error
overlay, the custom elements, `morphdom`, and the devtools with
`features/inspect.ts`.

`protocol/msgpack.ts` is a codec for the part of MessagePack the protocol
uses, in place of a general-purpose library that was two fifths of the
bundle. `@msgpack/msgpack` remains a dev dependency: `msgpack.test.ts`
compares the two on random values, and decodes bytes packed by Ruby.

`npm run size` builds and prints every chunk, and fails when the eager chunks
outgrow the budget in `scripts/check-size.js`. Lower the budget when a change
shrinks them.

## The protocol, defined once

`docs/protocol.md` at the root of the repository describes the wire
protocol: the requests, both streams, and what happens on a reconnect.

`../protocol.json` lists the commands, events, error codes, continuous event
types and element methods. `protocol-manifest.test.ts` checks this runtime
against it, and `lib/mayu/protocol.test.rb` checks the server.

## Tests

Vitest with jsdom; tests sit next to the module they cover.

- `npm test -w gems/mayu-live/lib/mayu/client` runs the tests and the size check.
- `npm run typecheck -w gems/mayu-live/lib/mayu/client`
