# Mayu DevTools

A browser devtools extension for Mayu Live apps, for Chrome and Firefox. It
adds:

- a **Mayu** panel with the component tree of the page, which refreshes as the
  page updates. Hovering a row highlights what it renders in the page.
  Selecting a row shows its details: a component's props (`$title`), state
  (`@count`), context (`@@theme`), instance variables and the events its
  methods handle, or an element's attributes and event handlers. _Show in
  Elements_ selects it in the Elements panel. Elements show their classes as
  written in the source (`<a.title>`), not the generated ones.
- a **Mayu** pane in the Elements panel's sidebar, showing the components that
  render the selected element, the element's event handlers, and the props and
  state of its component. Selecting an element also selects its component in
  the Mayu panel.

Devtools only work against `mayu dev`, which installs the server side
(`Mayu::Devtools` in this gem).

## Building

```sh
npm install
npm -w gems/mayu-devtools/extension run build
```

This writes an unpacked extension to `dist/chrome` and `dist/firefox`.
`npm -w gems/mayu-devtools/extension run watch` rebuilds on changes.

## Loading

- **Chrome:** open `chrome://extensions`, enable Developer mode, choose _Load
  unpacked_, and pick `dist/chrome`.
- **Firefox 128+:** open `about:debugging#/runtime/this-firefox`, choose _Load
  Temporary Add-on…_, and pick `dist/firefox/manifest.json`. Firefox may ask
  you to allow the extension on the site before its content scripts run.

Reload the inspected page after loading the extension: the hook has to be in
place before Mayu starts.

## How it works

```
panel / sidebar  <-port->  background  <-runtime messages->  bridge.ts
  (isolated world)  <-postMessage->  hook.ts (page world)  <-register->  Mayu client
```

- `hook.ts` runs in the page's world at `document_start` and defines
  `window.__MAYU_DEVTOOLS_HOOK__`. Mayu's client registers with it (see
  `client/src/devtools.ts` in mayu-live), giving it DOM node ↔ vnode id lookups,
  batch notifications, and `inspect(query)`.
- `inspect` sends an `Inspect` event to the session, which answers with an
  `InspectResult` command from `Mayu::Devtools::Inspector`.
- The devtools use `inspectedWindow.eval` for `$0` and `inspect()`, so the
  Elements panel selection maps to vnode ids through the hook.
