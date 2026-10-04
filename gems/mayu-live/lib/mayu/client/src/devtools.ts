// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import type { Batch } from "./protocol";

// The API a devtools extension receives. The extension defines
// window.__MAYU_DEVTOOLS_HOOK__ before the page loads, and Mayu registers
// with it if it's there.
export type DevtoolsApi = {
  version: 1;
  node(id: string): Node | undefined;
  nodeId(node: Node): string | undefined;
  inspect(query: Record<string, unknown>): Promise<unknown>;
  onBatch(listener: (batch: Batch, durationMs: number) => void): () => void;
};

export type DevtoolsHook = {
  register(api: DevtoolsApi): void;
};

declare global {
  interface Window {
    __MAYU_DEVTOOLS_HOOK__?: DevtoolsHook;
  }
}

type Inspectable = {
  node(id: string): Node | undefined;
  nodeId(node: Node): string | undefined;
};

type Inspector = {
  inspect(query: Record<string, unknown>): Promise<unknown>;
};

// Commands that don't change the page: answers to pings and to devtools' own
// queries. Reporting InspectResult would make a devtools that refreshes after
// each batch loop forever.
const UNREPORTED_COMMANDS = new Set([
  "InspectResult",
  "Pong",
  "CallbackComplete",
  "CallbackFailed",
]);

export default class Devtools {
  #listeners = new Set<(batch: Batch, durationMs: number) => void>();

  register(runtime: Inspectable, mayu: Inspector) {
    window.__MAYU_DEVTOOLS_HOOK__?.register({
      version: 1,
      node: (id) => runtime.node(id),
      nodeId: (node) => runtime.nodeId(node),
      inspect: (query) => mayu.inspect(query),
      onBatch: (listener) => {
        this.#listeners.add(listener);
        return () => this.#listeners.delete(listener);
      },
    });
  }

  batchApplied(batch: Batch, durationMs: number) {
    if (batch.every(([name]) => UNREPORTED_COMMANDS.has(name))) return;

    for (const listener of this.#listeners) listener(batch, durationMs);
  }
}
