// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// The devtools' end of the message relay: a port to the background script,
// which passes messages on to the inspected tab.

import { PORT_NAME, type DevtoolsMessage, type PageMessage } from "./messages";

// Longer than the client's own inspect timeout, which answers with an error.
const INSPECT_TIMEOUT = 10_000;
const RECONNECT_DELAY = 250;

type PendingInspect = {
  resolve: (result: unknown) => void;
  reject: (error: Error) => void;
  timer: ReturnType<typeof setTimeout>;
};

export default class Connection {
  #port: chrome.runtime.Port | null = null;
  #listeners = new Set<(message: PageMessage) => void>();
  #pending = new Map<string, PendingInspect>();
  #sequence = 0;

  constructor() {
    this.#connect();
  }

  // Asks the page to announce itself if Mayu has registered with the hook.
  hello() {
    this.#send({ type: "hello" });
  }

  inspect(query: Record<string, unknown>): Promise<unknown> {
    const requestId = `${++this.#sequence}`;

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.#pending.delete(requestId);
        reject(new Error("The page did not answer"));
      }, INSPECT_TIMEOUT);
      this.#pending.set(requestId, { resolve, reject, timer });
      this.#send({ type: "inspect", requestId, query });
    });
  }

  subscribe(listener: (message: PageMessage) => void) {
    this.#listeners.add(listener);
    return () => {
      this.#listeners.delete(listener);
    };
  }

  #connect() {
    const port = chrome.runtime.connect({ name: PORT_NAME });
    port.postMessage({
      type: "init",
      tabId: chrome.devtools.inspectedWindow.tabId,
    });
    port.onMessage.addListener((message: PageMessage) =>
      this.#receive(message),
    );
    // Chrome stops an idle background service worker, which disconnects the
    // port. Requests in flight time out.
    port.onDisconnect.addListener(() => {
      this.#port = null;
      setTimeout(() => this.#connect(), RECONNECT_DELAY);
    });
    this.#port = port;
  }

  #send(message: DevtoolsMessage) {
    this.#port?.postMessage(message);
  }

  #receive(message: PageMessage) {
    if (message.type === "inspect-result") {
      const pending = this.#pending.get(message.requestId);
      if (!pending) return;

      this.#pending.delete(message.requestId);
      clearTimeout(pending.timer);
      if (message.error) {
        pending.reject(new Error(message.error));
      } else {
        pending.resolve(message.result);
      }
      return;
    }

    for (const listener of this.#listeners) listener(message);
  }
}
