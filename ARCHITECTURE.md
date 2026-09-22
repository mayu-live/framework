# Mayu Architecture (for Coding Agents)

## What This Project Is

Mayu is a server-rendered UI framework with server-side component state and a browser runtime that applies streamed DOM patches.

The server renders HTML for the initial request, then keeps a per-browser session alive. Client events are sent back to the server, the server re-renders/diffs server-side vnode trees, and the browser applies command batches.

## Mental Model

- Server owns application state and component instances.
- Components render descriptor trees (not direct DOM).
- Runtime converts descriptors to server-side vnodes and diffs them into commands.
- Browser runtime executes those commands against the real DOM.
- Klenod compiles application files (`.haml`, `.css`, `.js`, and assets), resolves routes, tracks dependencies, and provides development updates for HMR.

## Top-Level Responsibility Map (`gems/mayu-live/lib/mayu`)

- `environment.rb`: Bootstraps the Klenod-backed app environment, metrics, runtime JS entry path, and marshaller.
- `server.rb` + `server/*`: HTTP server, routing of framework endpoints, session stream/event handling, static runtime files.
- `session.rb` + `session/*`: Per-client session lifecycle, event queueing, runtime engine orchestration, transfer/resume.
- `runtime.rb` + `runtime/*`: Server-side rendering/diff engine, vnode tree, command generation, serialization.
- `component.rb` + `component/*`: Base component API, fetch helper, and CSS unit refinements. Klenod supplies generated component class names.
- `klenod.rb` + `klenod/*`: the runtime half of Mayu's Klenod boundary: module provider, router, and asset adapter. Needs only klenod-runtime and klenod-rack.
- `build.rb` + `build/*` (in `gems/mayu-build`): the build half: Klenod configuration and plugins, the development provider, hot reloading, and every CLI command except `start`. This is what the `mayu-build` gem ships.
- `configuration.rb`: `mayu.toml` loading and environment config resolution.
- `cli.rb`: the `mayu` executable. Hands every invocation to `Mayu::Build::CLI` when mayu-build is installed; otherwise it knows only `start`, parsed with the standard library, and tells you to install mayu-build for anything else.
- `metrics.rb` + `metrics/*`: Prometheus metrics, multi-process collection/export.
- `client/`: Browser runtime TypeScript workspace (batch consumer + session connection).

## End-to-End Flow (Request -> Session -> Commands)

1. `Mayu::Build::Commands::Dev` / `Mayu::CLI.start` creates `Mayu::Server` with a loader for the worker's `Mayu::Environment`.
2. `Mayu::Server::Controller` starts worker process(es) and loads `Mayu::Environment`.
3. `Mayu::Server::App` handles HTTP requests.
4. First HTML GET (non-`/.mayu`, `Accept: text/html`) creates `Mayu::Session`.
5. `Session` resolves route and builds a root descriptor (root layout + nested page layouts + page).
6. `Session` creates `Mayu::Runtime::Engine`, which builds a `VDocument` vnode tree.
7. `App#handle_session_start` returns SSR HTML plus `x-mayu-session-id` and session token cookie.
8. Browser loads `/.mayu/runtime/...` JS, connects to `/.mayu/session/:id`.
9. Server streams one bootstrap batch containing `Initialize` and the current
   `SetListener` registrations, followed by command batches
   (`application/vnd.mayu.event-stream`).
10. Browser sends callback/navigate/ping events to `PATCH /.mayu/session/:id`.
11. Session queues events -> engine updates -> command batches streamed back.

## Core Runtime Architecture (`gems/mayu-live/lib/mayu/runtime`)

### Key layers

- `Runtime::H`: helper to build descriptor objects.
- `Runtime::Descriptors`: immutable render descriptors (`Element`, `Children`, `Context`, `Callback`, etc.).
- `Runtime::VNodes::*`: stateful vnode tree used for diffing, lifecycle, listeners, serialization.
- `Runtime::Engine`: orchestrates vnode root, updater queue, dirty element flushing, and the batch output queue.
- `Runtime::Commands`: compact server-to-client command types; `Runtime::Batch` is one ordered transport message.

### Rendering and updates

- `Engine` owns a `VDocument` root and an async batch output queue.
- `VDocument` wraps app output with internal `Html`/`Head` components and tracks:
  - listeners
  - aggregated head nodes
  - stylesheet dependencies
  - custom elements
- `VComponent` is the main stateful vnode:
  - instantiates component class
  - maintains component context
  - runs `mount`/`unmount`
  - exposes `rerender!` into engine updater queue
  - supports error boundaries (`handle_error`)
- `VChildren` performs child diffing and emits structural commands:
  - `CreateTree` for inserts
  - `RemoveNode`
  - `ReplaceChildren` when child ID lists change
  - chunked updates using `Engine#update_budget`
- A `ReplaceChildren` command carries the ordered IDs of the direct DOM nodes
  contributed by an element's vnode children. Components, contexts, slots, and
  other wrapper vnodes contribute the top-level DOM nodes they render, so a
  component that renders several siblings contributes several IDs. The client
  uses that list to retain existing nodes, remove absent ones, and insert or
  move nodes into the server's order.
- `VAttributes` handles attribute/class/style diffs and retains callback
  listener descriptors. `VDocument` derives the dispatch index from committed
  VDOM state; callback wiring is not rendered into SSR HTML and is sent as
  `SetListener`/`RemoveListener` commands.

### Important invariants

- Server-side vnodes, engine, and sessions are marshalable for transfer/resume.
- Async tasks are excluded from marshal state and rebuilt on rehydrate.
- `VComponent` is the vnode that owns long-lived async work (component task/queue).
- Command ordering matters within each batch:
  - navigation/history commands
  - head commands
  - body commands
  - listener commands for new subtrees follow their `CreateTree` command
- Each updater flush produces one batch. Standalone commands use singleton
  batches, and the server never merges adjacent batches.
- Each queued VDOM update starts with a command checkpoint. If a parent error
  boundary handles a render failure, commands from that failed attempt are
  discarded and the boundary subtree is rebuilt from its fallback render.

### Error boundaries

- A component becomes an error boundary by defining `handle_error(error)` and
  returning a truthy value when it has updated itself to render a fallback.
- Boundaries catch render failures from descendants, not their own render or
  callback failures.
- A falsey handler continues the search at the next parent. If a handler or
  fallback raises, the new error also continues at the next parent.
- Handled failures synchronously replace the boundary subtree. Unrelated VDOM
  updates already collected for the same batch are preserved.
- Unhandled errors are always logged. `server.render_exceptions` controls
  whether the server also sends a `RenderError` command for the browser overlay.

## Components (`gems/mayu-live/lib/mayu/component`)

### Base API

`Mayu::Component::Base` is the base class for app components and Haml-generated components.

Key responsibilities:

- `render` returns descriptors (usually via `H[...]`).
- `mount` / `unmount` lifecycle hooks.
- `should_update?` exists but is not consulted. A vnode handed the descriptor object it
  already holds is skipped instead (`VComponent#unchanged?`); a context provider whose
  values changed forces its subtree through `Engine#force_render`.
- `sleep` inside a component is runtime-aware: while the page is hidden, short sleeps are
  stretched to the engine's `update_interval`.
- `rerender!` is injected by `VComponent` when mounted.
- `@__props`, `@__children`, `@__context` are runtime-managed internal state.

### Helpers

- `Component::Fetch`: server-side HTTP fetch helper.
- `CSSUnits::Refinements`: ergonomic CSS unit values used in component code/styles.

## Routing, Modules, and Assets (Klenod)

Mayu delegates source loading, transforms, routing, assets, source maps, and
file watching to Klenod. `Mayu::Build::Configuration` supplies the framework
defaults: `app` as the source directory, `app/pages` as the route directory,
Klenod Haml configured with Mayu's component base and VDOM factory, and
Klenod's Ruby, CSS, JavaScript, image, SVG, JSON, and static-file plugins.

### Router model

`Klenod::Router` resolves routes from `app/pages`. Route files use
`+page.haml`, `+layout.haml`, `+not-found.haml`, `+error.haml`, and optional
`+route.rb` HTTP handlers. Klenod supports static, dynamic (`[id]`), catch-all
(`[...]`), optional catch-all, grouped, parallel, and intercepted segments.

### Session route resolution

`Session#resolve_route` asks `Klenod::Router` for a resolved page descriptor.
The result contains the VDOM tree, HTTP status, canonical module IDs, and the
ordered CSS and JavaScript assets for the route. Mayu passes the descriptor and
asset URLs to its existing VDOM/runtime engine. Route-resolution failures use
the nearest Klenod `+error` view; initial and live VDOM failures retain Mayu's
error-boundary/render-error-command behavior.

### Development and production

In development, one Klenod watcher invalidates the shared graph and Mayu fans
each update out to live sessions. In production, `mayu build` materializes
Klenod assets and serializes a Klenod runtime bundle; `mayu start` loads that
bundle through the production provider. `Klenod::Rack::AssetApp` serves assets
at `/.mayu/assets/`.

## Server and Session Transport (`gems/mayu-live/lib/mayu/server`, `gems/mayu-live/lib/mayu/session`)

### `Server::App` endpoint split

- App HTML route (new session): `GET /...` with `Accept: text/html`
- Runtime JS: `GET /.mayu/runtime/...`
- Init JS shim: `GET /.mayu/init.js`
- Assets: `GET /.mayu/assets/...`
- Session stream resume: `GET /.mayu/session/:id`
- Session transfer resume: `POST /.mayu/session/:id`
- Incoming events: `PATCH /.mayu/session/:id`
- CORS preflight for framework path: `OPTIONS /.mayu`

### Session state and security

- Session IDs are opaque random IDs.
- Session token is separate cookie-scoped secret (`mayu-token`) used to authorize session endpoints.
- `Session::Token.equal?` uses constant-time compare (`RbNaCl::Util.verify64`).
- Session transfer payloads are encrypted + time-limited via `EncryptedMarshal`.

### Transfer/resume behavior

On shutdown or an explicit transfer command:

- session serializes (`Marshal.dump`)
- wrapped in `Session::TransferState`
- encrypted (`EncryptedMarshal`)
- sent as a `Runtime::Commands::Transfer` blob in a singleton batch
- browser stores transfer blob
- next stream connect uses `POST` with transfer blob to resume session

## Browser Runtime (`gems/mayu-live/lib/mayu/client/src`)

### Main pieces

- `main.ts`: entrypoint called by server-generated init shim.
- `session-connection.ts`: reconnect loop, stream setup, batch decoding, callback stream setup.
- `stream.ts`: HTTP stream connect helpers for command stream + outgoing event stream/fallback.
- `runtime.ts`: command dispatcher against real DOM + node ID registry.
- `mayu.ts`: `window.Mayu` bridge for callbacks/navigation/pings.
- `serializeEvent.ts`: serializes DOM event payloads.
- `client-event-codec.ts`: encodes, frames, and optionally compresses
  client-to-server event tuples.
- `session-recovery.ts`: full-session reset fallback (re-fetch page + morph DOM) for unrecoverable session errors.

### Command protocol boundary

Ruby command types in `gems/mayu-live/lib/mayu/runtime/commands.rb` must stay in sync with
command handlers in `gems/mayu-live/lib/mayu/client/src/runtime.ts`.

Every decoded MessagePack value is a batch (`Command[]`), and every command is
a compact `[name, ...arguments]` tuple. There is no `Batch` command or extra
transport wrapper. `ViewTransition` is the only command that intentionally
contains a nested batch.

Notable command categories:

- tree creation/removal (`CreateTree`, `RemoveNode`)
- child replacement (`ReplaceChildren`)
- attributes/classes/styles/text
- navigation (`HistoryPushState`)
- head/error/custom elements
- transfer blob
- view-transition batches (`ViewTransition`)

### Client/server event loop

- browser sends framed MessagePack tuples to `PATCH /.mayu/session/:id`;
  messages are at-most-once and are dropped rather than replayed across
  disconnects
- each frame has an encoding byte and a 32-bit payload length; larger event
  payloads use independent `deflate-raw` compression
- request streaming and the per-request fallback use the same frame format
- server parses frames in `Server::EventStream.each_incoming_message`
- `Session#receive_message` turns each tuple into exactly one typed event
  (`CallbackEvent`, `NavigateEvent`, or `PingEvent`)
- callbacks are serialized per component while different components can run
  concurrently
- server-to-client: `VDOM -> CommandCollector -> Batch -> Engine queue -> stream -> applyBatch -> DOM`
- client-to-server: `browser event -> tuple -> MessagePack frame -> receive_message -> session event -> callback/navigation -> VDOM`
- command batches are streamed as deflate-raw compressed MessagePack arrays

## Environment and Build Modes (`environment.rb`, `commands/*`)

### Development

- `Commands::Dev`
- Klenod development provider loads app source and resolves routes
- Klenod's watcher drives HMR updates
- Klenod asset plugins generate changed assets
- route changes are applied through Klenod's router update

### Production

- `Commands::Build`: builds Klenod routes and assets, then serializes the environment bundle
- `Commands::Start`: loads bundle + runs server
- bundle stores the marshaled Klenod provider plus version metadata

## Metrics (`gems/mayu-live/lib/mayu/metrics`)

Metrics are integrated across server/session/runtime.

Examples:

- active session count
- session init/timeout/ping/callback/navigate counters
- component mount/update timing summaries
- update chunking/child ID update counters

In multi-process mode, worker reporters push metrics to a collector server, which exports Prometheus text format.

## Where To Make Changes (Practical Guide)

- Change component API/lifecycle/state behavior:
  - `gems/mayu-live/lib/mayu/component/base.rb`
  - `gems/mayu-live/lib/mayu/runtime/vnodes/vcomponent.rb`
- Change diffing/command emission:
  - `gems/mayu-live/lib/mayu/runtime/vnodes/*`
  - `gems/mayu-live/lib/mayu/runtime/commands.rb` (wire commands; also update TS handlers)
  - `gems/mayu-live/lib/mayu/client/src/runtime.ts`
- Change event serialization or callback semantics:
  - `gems/mayu-live/lib/mayu/client/src/serializeEvent.ts`
  - `gems/mayu-live/lib/mayu/runtime/vnodes/vattributes.rb`
  - `gems/mayu-live/lib/mayu/session.rb` (`Events.parse`)
- Change route/file conventions:
  - `gems/mayu-build/lib/mayu/build/configuration.rb`
  - `gems/mayu-live/lib/mayu/klenod/router.rb`
  - `gems/mayu-live/lib/mayu/session.rb` (`resolve_route`)
- Change app import/compile behavior:
  - `gems/mayu-build/lib/mayu/build/configuration.rb`
  - the corresponding Klenod plugin
- Change HMR reload behavior:
  - `gems/mayu-build/lib/mayu/build/hot_reloader.rb`
  - `gems/mayu-live/lib/mayu/hot_reload.rb` (the update handed to sessions)
  - `gems/mayu-live/lib/mayu/session.rb` (`notify_hmr_update`)
- Change asset generation/serving:
  - Klenod asset plugins
  - `gems/mayu-live/lib/mayu/klenod/asset_app.rb`
  - `gems/mayu-live/lib/mayu/server/app.rb#handle_asset`
- Change session auth/transfer/recovery:
  - `gems/mayu-live/lib/mayu/server/cookies.rb`
  - `gems/mayu-live/lib/mayu/session/*`
  - `gems/mayu-live/lib/mayu/encrypted_marshal.rb`
  - `gems/mayu-live/lib/mayu/client/src/session-connection.ts`
  - `gems/mayu-live/lib/mayu/client/src/session-recovery.ts`

## Sharp Edges / Agent Notes

- Session/engine transfer relies on `Marshal`; avoid storing non-marshalable objects in component instance state.
- Keep the command schema aligned across Ruby and TypeScript.
- `VChildren` diffing uses a simple keyed/type reconciliation strategy; keyed reordering works, but it favors simplicity over advanced move-optimization (e.g. explicit move commands/LIS-style minimization).
- `VBody` injects a `<mayu-ping>` custom element automatically for connection status UI.

## Good Starting Files for New Contributors

- `gems/mayu-live/lib/mayu/server/app.rb`
- `gems/mayu-live/lib/mayu/session.rb`
- `gems/mayu-live/lib/mayu/runtime/engine.rb`
- `gems/mayu-live/lib/mayu/runtime/vnodes/vdocument.rb`
- `gems/mayu-live/lib/mayu/runtime/vnodes/vcomponent.rb`
- `gems/mayu-live/lib/mayu/runtime/vnodes/vchildren.rb`
- `gems/mayu-live/lib/mayu/modules/system.rb`
- `gems/mayu-live/lib/mayu/modules/README.md`
- `gems/mayu-live/lib/mayu/client/src/session-connection.ts`
- `gems/mayu-live/lib/mayu/client/src/runtime.ts`
