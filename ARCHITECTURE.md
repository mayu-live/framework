# Mayu Architecture (for Coding Agents)

## What This Project Is

Mayu is a server-rendered UI framework with server-side component state and a browser runtime that applies streamed DOM patches.

The server renders HTML for the initial request, then keeps a per-browser session alive. Client events are sent back to the server, the server re-renders/diffs server-side vnode trees, and the browser applies patch batches.

## Mental Model

- Server owns application state and component instances.
- Components render descriptor trees (not direct DOM).
- Runtime converts descriptors to server-side vnodes and emits patch operations.
- Browser runtime applies patch operations to real DOM.
- A module system (`lib/mayu/modules`) compiles app files (`.haml`, `.css`, `.js`, assets) into Ruby modules and tracks dependencies for HMR.

## Top-Level Responsibility Map (`lib/mayu`)

- `environment.rb`: Bootstraps app environment (config, router, module system, metrics, runtime JS entry path, marshaller).
- `server.rb` + `server/*`: HTTP server, routing of framework endpoints, session stream/event handling, static runtime files.
- `session.rb` + `session/*`: Per-client session lifecycle, event queueing, runtime engine orchestration, transfer/resume.
- `runtime.rb` + `runtime/*`: Server-side rendering/diff engine, vnode tree, patch generation, serialization.
- `component.rb` + `component/*`: Base component API and component helpers (stylesheets, fetch helper, CSS unit refinements).
- `modules.rb` + `modules/*`: App module loader/compiler, dependency graph, imports, HMR reload, source maps/backtrace rewriting.
- `assets.rb` + `assets/*`: Asset generation/storage pipeline used by module loaders and server asset endpoint.
- `routes.rb`: File-system router (`app/pages`) to route matches and layout composition.
- `configuration.rb`: `mayu.toml` loading and environment config resolution.
- `commands/*`: CLI commands (`dev`, `build`, `start`, etc.).
- `metrics.rb` + `metrics/*`: Prometheus metrics, multi-process collection/export.
- `watcher.rb`: File watcher integration for dev/HMR.
- `client/`: Browser runtime TypeScript workspace (patch consumer + session connection).

## End-to-End Flow (Request -> Session -> Patches)

1. `Mayu::Commands::Dev` / `Start` creates `Mayu::Server`.
2. `Mayu::Server::Controller` starts worker process(es) and loads `Mayu::Environment`.
3. `Mayu::Server::App` handles HTTP requests.
4. First HTML GET (non-`/.mayu`, `Accept: text/html`) creates `Mayu::Session`.
5. `Session` resolves route and builds a root descriptor (root layout + nested page layouts + page).
6. `Session` creates `Mayu::Runtime::Engine`, which builds a `VDocument` vnode tree.
7. `App#handle_session_start` returns SSR HTML plus `x-mayu-session-id` and session token cookie.
8. Browser loads `/.mayu/runtime/...` JS, connects to `/.mayu/session/:id`.
9. Server streams `Initialize` + patch batches (`application/vnd.mayu.event-stream`).
10. Browser sends callback/navigate/ping events to `PATCH /.mayu/session/:id`.
11. Session queues events -> engine updates -> patch batches streamed back.

## Core Runtime Architecture (`lib/mayu/runtime`)

### Key layers

- `Runtime::H`: helper to build descriptor objects.
- `Runtime::Descriptors`: immutable render descriptors (`Element`, `Children`, `Context`, `Callback`, etc.).
- `Runtime::VNodes::*`: stateful vnode tree used for diffing, lifecycle, listeners, serialization.
- `Runtime::Engine`: orchestrates vnode root, updater queue, dirty element flushing, patch output queue.
- `Runtime::Patches`: patch protocol types (Ruby side). Generated file; keep Ruby/TS patch names aligned.

### Rendering and updates

- `Engine` owns a `VDocument` root and an async patch output queue.
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
- `VChildren` performs child diffing and emits structural patches:
  - `CreateTree` for inserts
  - `RemoveNode`
  - `ReplaceChildren` when child ID lists change
  - chunked updates using `Engine#update_budget`
- `VAttributes` handles attribute/class/style diffs and callback listener wiring.

### Important invariants

- Server-side vnodes, engine, and sessions are marshalable for transfer/resume.
- Async tasks are excluded from marshal state and rebuilt on rehydrate.
- `VComponent` is the vnode that owns long-lived async work (component task/queue).
- Patch ordering matters:
  - navigation/history patches
  - head patches
  - body patches
- `lib/mayu/runtime/patches.rb` is generated (`DO NOT EDIT` comment).

## Components (`lib/mayu/component`)

### Base API

`Mayu::Component::Base` is the base class for app components and Haml-generated components.

Key responsibilities:

- `render` returns descriptors (usually via `H[...]`).
- `mount` / `unmount` lifecycle hooks.
- `should_update?` exists but current vnode path primarily rerenders and diffs children.
- `rerender!` is injected by `VComponent` when mounted.
- `@__props`, `@__children`, `@__context` are runtime-managed internal state.

### Helpers

- `Component::StyleSheets`: merges CSS module exports and class lookups.
- `Component::Fetch`: server-side HTTP fetch helper.
- `CSSUnits::Refinements`: ergonomic CSS unit values used in component code/styles.

## Routing and Page Composition (`lib/mayu/routes.rb`, `lib/mayu/session.rb`)

### Router model

`Mayu::Routes::Router` builds routes from `app/pages`.

Supported segments:

- plain directory -> literal segment
- `:id` -> param segment
- `::rest` -> splat param (must be last)
- `(group)` -> grouping segment (no URL path part)

Per-directory view files:

- `page.haml`
- `layout.haml`
- `template.haml` (reserved in router model)
- `not_found.haml`

### Session route resolution

`Session#resolve_route` builds the render descriptor stack:

- imports `root.haml`
- imports matched page and layout modules via module system
- wraps page in layouts from inside-out (reverse reduce)
- passes `params`, `query`, and `path` props as appropriate

If route lookup fails, session uses `Session::ErrorPage`.

## Module System / App Compiler (`lib/mayu/modules`)

This is the app-loading subsystem for components, styles, assets, and HMR.

### Core classes

- `Modules::System`: thread-local active module system (`System.current`), import API, reload orchestration.
- `Modules::Resolver`: resolves import paths relative to source module.
- `Modules::Mod`: one loaded module/file with dependencies, dependants, transformed source, source map, assets.
- `Modules::Registry`: stores module instances as constants for stable references and lookup.
- `Modules::ImportRewriter`: rewrites `import("...")` calls to stable hashed import IDs and records dependency mapping.
- `Modules::BacktraceRewriter` / `SourceMap`: maps runtime errors back to original Haml/Ruby source.

### Loading pipeline

`System#import(path, source)`:

1. resolve path
2. load file source
3. apply matching loader rules (`SYSTEM_CONFIG`)
4. rewrite `import(...)` calls to hashed imports
5. build source map
6. evaluate transformed Ruby into `Mod::Exports`
7. return `Exports::Default`

### Loader responsibilities (`lib/mayu/modules/loaders`)

- `Haml`: Haml -> Ruby AST/code -> wrapped component class inheriting `Mayu::Component::Base`.
- `Ruby`: wraps Ruby files into module export shape.
- `CSS`: CSS modules transform -> `Mayu::StyleSheet` export + asset generation.
- `JavaScript`: packages JS as a `Mayu::CustomElement` and emits asset text file.
- `Image`: exports `Mayu::Image` metadata and enqueues resized image assets.
- `SVG`: exports `Mayu::SVG` metadata and enqueues SVG asset text.
- `StaticFile`: exports hashed public asset path and enqueues file copy.
- `JSON`: exports deep-frozen parsed JSON.

### HMR / file watching

- `Watcher` emits create/update/delete events.
- `Environment#start_watcher` rebuilds router when page/layout files change.
- `Modules::System#handle_watch_events` stages source updates, computes dirty modules + dependants, reloads in topological order, and signals waiting sessions.
- Sessions listening for reload (`Session#run_code_reload_task`) call `Engine#refresh` and emit `reload:success` or `RenderError` patches.

## Assets Pipeline (`lib/mayu/assets`)

Assets are produced by module loaders and served by the framework.

### Flow

1. Loader calls `add_asset(...)` while module code evaluates.
2. Asset generator is enqueued in `Assets::Storage`.
3. In dev, asset generation task may run continuously.
4. In build, assets are generated before writing bundle.
5. `Server::App#handle_asset` serves generated assets from `/.mayu/assets/...`.

### Asset representations

- `Assets::Asset`: filename + headers + encoded content strategy.
- `Assets::EncodedContent`: in-memory content (optionally Brotli compressed).
- `Assets::FileContent`: sentinel meaning serve from file on disk.
- Generators:
  - `Text`
  - `Image`
  - `WriteFile`

## Server and Session Transport (`lib/mayu/server`, `lib/mayu/session`)

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

On shutdown or explicit transfer patch:

- session serializes (`Marshal.dump`)
- wrapped in `Session::TransferState`
- encrypted (`EncryptedMarshal`)
- sent as `Runtime::Patches::Transfer` blob
- browser stores transfer blob
- next stream connect uses `POST` with transfer blob to resume session

## Browser Runtime (`lib/mayu/client/src`)

### Main pieces

- `main.ts`: entrypoint called by server-generated init shim.
- `session-connection.ts`: reconnect loop, stream setup, patch decoding, callback stream setup.
- `stream.ts`: HTTP stream connect helpers for patch stream + outgoing event stream/fallback.
- `runtime.ts`: patch executor against real DOM + node ID registry.
- `mayu.ts`: `window.Mayu` bridge for callbacks/navigation/pings.
- `serializeEvent.ts`: serializes DOM events to JSON payloads.
- `session-recovery.ts`: full-session reset fallback (re-fetch page + morph DOM) for unrecoverable session errors.

### Patch protocol boundary

Ruby patch types in `lib/mayu/runtime/patches.rb` must stay in sync with patch handlers in `lib/mayu/client/src/runtime.ts`.

Notable patch categories:

- tree creation/removal (`CreateTree`, `RemoveNode`)
- child replacement (`ReplaceChildren`)
- attributes/classes/styles/text
- navigation (`HistoryPushState`)
- head/error/custom elements
- transfer blob
- batched patches (`Batch`) and view transitions (`ViewTransition`)

### Client/server event loop

- browser sends JSON lines to `PATCH /.mayu/session/:id`
- server parses messages in `Server::EventStream.each_incoming_message`
- session turns messages into typed events (`CallbackEvent`, `NavigateEvent`, `PingEvent`)
- runtime processes and streams MsgPack patch arrays back (deflate-raw compressed)

## Environment and Build Modes (`environment.rb`, `commands/*`)

### Development

- `Commands::Dev`
- live module system from app source
- optional file watcher/HMR
- optional ongoing asset generation
- router can rebuild on page/layout file changes

### Production

- `Commands::Build`: preloads routes/templates, generates assets, serializes environment bundle
- `Commands::Start`: loads bundle + runs server
- bundle stores marshaled `modules` and `router` plus version metadata

## Metrics (`lib/mayu/metrics`)

Metrics are integrated across server/session/runtime.

Examples:

- active session count
- session init/timeout/ping/callback/navigate counters
- component mount/update timing summaries
- update chunking/child ID update counters

In multi-process mode, worker reporters push metrics to a collector server, which exports Prometheus text format.

## Where To Make Changes (Practical Guide)

- Change component API/lifecycle/state behavior:
  - `lib/mayu/component/base.rb`
  - `lib/mayu/runtime/vnodes/vcomponent.rb`
- Change diffing/patch emission:
  - `lib/mayu/runtime/vnodes/*`
  - `lib/mayu/runtime/patches.rb` (generated; also update TS handlers)
  - `lib/mayu/client/src/runtime.ts`
- Change event serialization or callback semantics:
  - `lib/mayu/client/src/serializeEvent.ts`
  - `lib/mayu/runtime/vnodes/vattributes.rb`
  - `lib/mayu/session.rb` (`Events.from_message`)
- Change route/file conventions:
  - `lib/mayu/routes.rb`
  - `lib/mayu/session.rb` (`resolve_route`)
- Change app import/compile behavior:
  - `lib/mayu/modules/system.rb`
  - `lib/mayu/modules/loaders/*`
  - `lib/mayu/system_config.rb`
- Change HMR reload behavior:
  - `lib/mayu/watcher.rb`
  - `lib/mayu/modules/system.rb`
  - `lib/mayu/session.rb` reload task
- Change asset generation/serving:
  - `lib/mayu/assets/*`
  - `lib/mayu/modules/loaders/*`
  - `lib/mayu/server/app.rb#handle_asset`
- Change session auth/transfer/recovery:
  - `lib/mayu/server/cookies.rb`
  - `lib/mayu/session/*`
  - `lib/mayu/encrypted_marshal.rb`
  - `lib/mayu/client/src/session-connection.ts`
  - `lib/mayu/client/src/session-recovery.ts`

## Sharp Edges / Agent Notes

- `Modules::System.current` is thread-local. Imports/loaders assume a current system context.
- Session/engine transfer relies on `Marshal`; avoid storing non-marshalable objects in component instance state.
- Keep patch schema compatibility across Ruby and TypeScript.
- `VChildren` diffing uses a simple keyed/type reconciliation strategy; keyed reordering works, but it favors simplicity over advanced move-optimization (e.g. explicit move patches/LIS-style minimization).
- Some client patch handlers contain debug logging / incomplete handlers (`AddStyleSheet` currently stubbed).
- `VBody` injects a `<mayu-ping>` custom element automatically for connection status UI.

## Good Starting Files for New Contributors

- `lib/mayu/server/app.rb`
- `lib/mayu/session.rb`
- `lib/mayu/runtime/engine.rb`
- `lib/mayu/runtime/vnodes/vdocument.rb`
- `lib/mayu/runtime/vnodes/vcomponent.rb`
- `lib/mayu/runtime/vnodes/vchildren.rb`
- `lib/mayu/modules/system.rb`
- `lib/mayu/modules/README.md`
- `lib/mayu/client/src/session-connection.ts`
- `lib/mayu/client/src/runtime.ts`
