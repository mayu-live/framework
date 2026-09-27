// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Runs in the page's own JavaScript world before any page script, and defines
// the global that Mayu's client registers with (see devtools.ts in the
// client). The devtools also reach it with inspectedWindow.eval, which is how
// they map the element selected in the Elements panel ($0) to a vnode id.

import type {
  DevtoolsApi,
  DevtoolsHook,
} from "../../../mayu-live/lib/mayu/client/src/devtools";
import {
  FROM_DEVTOOLS,
  FROM_PAGE,
  isTagged,
  type DevtoolsMessage,
  type PageMessage,
} from "./messages";
import Highlighter from "./highlight";

// Batches can come in fast, and the devtools refetch the tree after each one.
const BATCH_DEBOUNCE = 100;

export type Hook = DevtoolsHook & {
  detected(): boolean;
  node(id: string): Node | null;
  idForNode(node: Node | null): string | null;
  highlight(ids: string[], label: string): void;
  hideHighlight(): void;
};

let api: DevtoolsApi | null = null;
let batchTimer: ReturnType<typeof setTimeout> | null = null;
const highlighter = new Highlighter((id) => api?.node(id) ?? null);

function post(message: PageMessage) {
  window.postMessage({ ...message, source: FROM_PAGE }, "*");
}

const hook: Hook = {
  register(registered) {
    if (registered.version !== 1) {
      console.warn(
        "Mayu DevTools: unsupported hook version",
        registered.version,
      );
      return;
    }

    api = registered;
    api.onBatch(() => {
      if (batchTimer !== null) clearTimeout(batchTimer);
      batchTimer = setTimeout(() => {
        batchTimer = null;
        post({ type: "batch" });
      }, BATCH_DEBOUNCE);
    });
    post({ type: "detected" });
  },

  detected() {
    return api !== null;
  },

  node(id) {
    return api?.node(id) ?? null;
  },

  // The id of the node, or of its closest ancestor Mayu knows about. Nodes
  // the page's own scripts added have none.
  idForNode(node) {
    for (let current = node; current; current = current.parentNode) {
      const id = api?.nodeId(current);
      if (id) return id;
    }
    return null;
  },

  // Draws boxes over the DOM nodes with the ids, labeled with the label.
  highlight(ids, label) {
    highlighter.show(ids, label);
  },

  hideHighlight() {
    highlighter.hide();
  },
};

async function answer(message: DevtoolsMessage) {
  switch (message.type) {
    case "hello":
      if (api) post({ type: "detected" });
      return;
    case "inspect": {
      const { requestId, query } = message;
      if (!api) {
        post({ type: "inspect-result", requestId, error: "Mayu not detected" });
        return;
      }
      try {
        const result = await api.inspect(query);
        post({ type: "inspect-result", requestId, result });
      } catch (error) {
        post({ type: "inspect-result", requestId, error: String(error) });
      }
    }
  }
}

if (!window.__MAYU_DEVTOOLS_HOOK__) {
  window.__MAYU_DEVTOOLS_HOOK__ = hook;

  window.addEventListener("message", (event) => {
    if (event.source !== window) return;
    if (!isTagged<DevtoolsMessage>(event.data, FROM_DEVTOOLS)) return;
    void answer(event.data);
  });
}
