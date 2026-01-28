# VNodes2 Rewrite Notes

This directory is the new virtual DOM implementation. The notes below summarize how the
current (vnodes/) implementation works and what we are changing for vnodes2.

## Current VNode implementation (vnodes/)

- Base class

  - Each vnode owns an `Updater` (Async task + queue). `apply` enqueues updates when
    running; otherwise it calls `update` directly.
  - `start` creates the updater; `stop` stops it.
  - `patch` delegates to parent; metrics and ancestor info are pulled from parent.

- VAny

  - Dispatches by descriptor type into one of VElement/VComponent/VText/etc.

- VChildren

  - Normalizes descriptors, inserts comment separators between adjacent strings.
  - Diffs by `Descriptors.same?` and produces Updated/Created/Removed sets.
  - Inserts/removes nodes and starts/stops them if the tree is running.
  - Maintains cached child ids and emits `ReplaceChildren` patches.

- VElement

  - Owns VAttributes + VChildren.
  - Uses DOM nesting validation; renders a DOM::Element.
  - Updates attributes and children on descriptor changes.

- VAttributes

  - Flattens props into attribute names.
  - Special cases `style`, `class`, and `on*` handlers (listener registry in VDocument).
  - Emits Set/Remove attribute patches on changes.

- VComponent

  - Allocates component instance, injects props/context/children.
  - Starts an async task to watch context changes, queue rerenders, and call mount.
  - On update, re-renders children and diffs them.

- VDocument

  - Root node; owns head/styles/registry for event listeners.
  - Internal Head component renders meta/title/links/stylesheets.

- VText/VComment/VHead/VBody/VSlot/VStateless/VCustomElement
  - Each implements render/update/insert/remove in the current patch model.

## Changes planned for VNodes2

- No Updater per vnode.

  - Only VComponent has an async task for lifecycle and rerendering.
  - Every vnode exposes `task`, which returns its own task or its parent’s task.

- Engine-owned updates

  - Each vnode stores a reference to the current Engine.
  - State changes (only in VComponent) call `@engine.enqueue_update(self)`.

- HTML writer API

  - Each vnode implements `write_html(out)` to render itself and children into a
    mutable output buffer.

- Tree initialization

  - The whole tree can be initialized without starting.
  - When a VComponent starts, it calls `mount`; when stopped, it calls `unmount`.

- New patching flow

  - Each vnode tracks whether it is new/inserted/removed.
  - `update(patcher)` will emit patches by appending to `patcher`:
    `patcher << Patches::InsertNode[...]`, etc.
  - No `patch(...)` delegation method on Base; patch emission is explicit.

- Structure
  - vnodes2 provides new base and child classes mirroring vnodes/, but rewritten to
    fit the new engine + patcher design.

## Implemented so far

- Base vnodes2 structure with stubs in `lib/mayu/runtime/vnodes2/`.
- VNode constructors now build child trees immediately (no implicit start).
- `write_html(out)` implemented for elements, text, comments, components, children,
  custom elements, and document.
- `dom_id` and `dom_id_tree` now emit `DOM::IdNode` trees for DOM-backed nodes.
- `Patcher` and `NullPatcher` for collecting or discarding patches.
- Diff/patch emission for:
  - insertions/removals via `Patches::CreateTree` and `Patches::RemoveNode`
  - text updates via `Patches::SetTextContent`
  - attribute updates via `Patches::SetAttribute` / `Patches::RemoveAttribute`
- ReplaceChildren batching:
  - VChildren marks nearest VElement dirty when direct child ids change.
  - Engine flushes dirty elements once per batch to emit `ReplaceChildren`.
- `start/stop` propagation and VComponent lifecycle (mount/unmount) with rerender!
  forwarding to `engine.enqueue_update(self)`.
- Insert/remove propagation independent of mount/unmount.
- Head registration via `VHead` insert/remove; head flush happens after batch updates.
- Stylesheet collection from component modules and injection into `<head>`.
- Updater + Engine queueing for batch updates and patch output.
- Event callback support:
  - `on*` attributes produce listener registration and JS callback wiring.
  - `Engine#callback` dispatches to listeners and triggers rerenders.
- Serialization support:
  - Engine and vnode trees are marshalable without async tasks.
  - Component state marshals via `Component::Base#marshal_dump`.
  - Rehydrate pass restores parent/engine links and listeners.
  - Engine `dump`/`dump!` and `restore`/`restore!` helpers.
  - VComponent stop is idempotent (mount/unmount only once).
- Tests in `lib/mayu/runtime/vnodes2.test.rb` for:
  - HTML rendering
  - patch creation on insert/remove
  - patch creation on attribute/text update
  - component rendering
  - component start/stop + rerender queueing
  - head registration and updates (including multiple titles)
  - update queue patch emission
  - ReplaceChildren emitted once per batch
  - stylesheet injection into head
  - event callback wiring and listener removal
  - engine callback dispatch emitting patches

## TODO (next steps)

- Attribute patch parity:
  - `class`/`style` diff patches (AddClass/RemoveClass, SetCSSProperty, etc).
  - Event listener patches parity (SetListener/RemoveListener vs SetAttribute).
- DOM patch parity:
  - Proper handling of keyed reordering (not just insert/remove).
- VHead/VDocument behavior:
  - Define head aggregation rules:
    - Always inject one `<meta charset="utf-8">` at the top.
    - Runtime JS `<script type="module">` should be present once (if configured).
    - For `<title>`, keep only the last title across all head nodes.
    - For `<meta name=...>`, keep only the last per `name`.
    - For `<meta property=...>`, keep only the last per `property`.
    - For `<link>` (e.g., stylesheets), keep only the last per `key` if provided,
      otherwise allow multiples (or define a dedupe key).
    - Preserve a stable ordering: runtime/meta/title/links first, then user tags
      in descriptor order of the last occurrence.
- Context/state:
  - Context invalidation + rerender scheduling when context values change.
- Custom elements:
  - `RegisterCustomElement` patch and update semantics in vnodes2.
- Error handling / RenderError patches on exceptions.
- Metrics integration.
- Bring remaining nodes to parity (VBody, VSlot, VStateless, etc).
