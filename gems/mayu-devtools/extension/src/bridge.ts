// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Runs in the extension's isolated world of the page. It relays messages
// between the hook in the page's world and the background script, since
// only the isolated world can talk to the extension.

import {
  FROM_DEVTOOLS,
  FROM_PAGE,
  isTagged,
  type PageMessage,
} from "./messages";

window.addEventListener("message", (event) => {
  if (event.source !== window) return;
  if (!isTagged<PageMessage>(event.data, FROM_PAGE)) return;

  const { source: _source, ...message } = event.data;
  // Throws once the extension is reloaded or removed, and rejects when no
  // devtools are listening. Neither matters to the page.
  try {
    chrome.runtime.sendMessage(message).catch(() => undefined);
  } catch {}
});

chrome.runtime.onMessage.addListener((message) => {
  window.postMessage({ ...message, source: FROM_DEVTOOLS }, "*");
});
