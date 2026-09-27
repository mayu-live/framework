// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Relays messages between each tab's bridge and the devtools open for it.
// Devtools connect with a port and name the tab they inspect first.

import { PORT_NAME } from "./messages";

const ports = new Map<number, Set<chrome.runtime.Port>>();

chrome.runtime.onConnect.addListener((port) => {
  if (port.name !== PORT_NAME) return;

  let tabId: number | null = null;

  port.onMessage.addListener((message) => {
    if (message.type === "init") {
      tabId = message.tabId as number;
      let tabPorts = ports.get(tabId);
      if (!tabPorts) ports.set(tabId, (tabPorts = new Set()));
      tabPorts.add(port);
      return;
    }

    if (tabId === null) return;
    // Rejects when the tab has no bridge, such as on a browser page.
    chrome.tabs
      .sendMessage(tabId, message, { frameId: 0 })
      .catch(() => undefined);
  });

  port.onDisconnect.addListener(() => {
    if (tabId === null) return;
    const tabPorts = ports.get(tabId);
    tabPorts?.delete(port);
    if (tabPorts?.size === 0) ports.delete(tabId);
  });
});

chrome.runtime.onMessage.addListener((message, sender) => {
  // Only the top frame: Mayu apps don't run in frames of each other.
  if (sender.tab?.id === undefined || sender.frameId !== 0) return;

  for (const port of ports.get(sender.tab.id) ?? []) {
    port.postMessage(message);
  }
});
