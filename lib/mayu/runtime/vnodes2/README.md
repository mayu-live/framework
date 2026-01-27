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
