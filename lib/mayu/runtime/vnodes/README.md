# VNodes (current implementation)

This directory contains the active virtual DOM implementation. It replaces the
legacy vnodes system and is now wired into `Mayu::Runtime::Engine` and sessions.

## What we implemented

### Core architecture

- Engine-driven updates (single updater queue).
- VComponent is the only vnode with a long-lived async task.
- Every vnode exposes `task` via parent fallback.
- `write_html(out)` renders the full tree without starting tasks.
- VNodes hold an Engine reference for updates/metrics/listeners.
- Base vnode lifecycle flags: new/inserted/removed.

### Patching and diffing

- `Patcher`/`NullPatcher` for collecting patches.
- Insert/remove: `CreateTree` + `RemoveNode`.
- Text updates: `SetTextContent`.
- Attribute updates: `SetAttribute`, `RemoveAttribute`, `AddClass`, `RemoveClass`,
  `SetCSSProperty`, `RemoveCSSProperty`.
- ReplaceChildren batching:
  - VChildren marks nearest VElement dirty when direct child ids change.
  - Engine flushes dirty elements once per batch.
- Batch ordering:
  - `HistoryPushState` patches are first.
  - Head patches come before body patches.
- `CreateTree` enforces a single `DOM::IdNode` root.
- Chunked updates with a configurable `update_budget` and metrics.

### Lifecycle + updates

- Start/stop propagate through tree.
- VComponent handles mount/unmount and rerender! → engine queue.
- Insert/remove propagate independently of mount/unmount.
- Components added while running start immediately; removed components stop.
- Removed nodes are marked and skipped during updates.

### Head + assets

- VHead registers with VDocument; insert/remove manage head set.
- Stylesheets collected from component modules.
- Custom elements:
  - `RegisterCustomElement` patches emitted for updates.
  - Inline registration scripts injected via head rendering.
  - Raw text vnode for script bodies.

### Events + callbacks

- `on*` attributes register listeners and emit JS callback wiring.
- `Engine#callback` dispatches into component tasks.
- Listener ids are serialized and rehydrated with component_map.
- Listener registration now happens during VAttributes init (not just render).

### Serialization

- Engine and vnode trees are marshalable (async tasks excluded).
- Component state marshals via `Component::Base#marshal_dump`.
- Rehydrate restores parent/engine links, component_map, and listeners.
- Engine helpers: `dump`, `dump!`, `restore`, `restore!`.

### Error handling + UX

- Error boundaries (component `handle_error`).
- Unhandled render errors emit `RenderError` patch with tree path.
- ViewTransition wrapper patch for queued component updates.

### Testing

- Tests are split under `lib/mayu/runtime/vnodes/__test__/`.
- Coverage includes:
  - HTML rendering + dom_id_tree
  - CreateTree/RemoveNode + ReplaceChildren
  - Attribute/class/style patches
  - Lifecycle (start/stop/mount/unmount)
  - Head aggregation and updates
  - Navigation patch ordering
  - Callback wiring + listener removal
  - Serialization round-trip + listener restore
  - Error boundaries + RenderError patch tree_path
  - Update budget chunking and removed-node skipping

## What changed recently

- Listener ids now serialize correctly and rehydrate to callbacks.
- Listeners register during attribute initialization.
- Engine queues listeners created before root exists.
- Serialization tests expect listeners to survive restore.
- Debug logging for listener restore removed.

## TODO / Follow-ups

- Event patch parity: `SetListener`/`RemoveListener` vs `SetAttribute`.
- Keyed reordering improvements beyond insert/remove.
- Head aggregation rules refinement (dedupe/ordering for title/meta/link).
- Context invalidation + rerender scheduling on context updates.
- Custom element registration on initial render without relying on updates.
- Evaluate update_budget defaults in production.
