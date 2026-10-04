// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Expressions evaluated in the inspected page, where the hook is reachable
// as a global and the console's $0 and inspect() are available.

const HOOK = "window.__MAYU_DEVTOOLS_HOOK__";

function evalInPage<T>(expression: string): Promise<T> {
  return new Promise((resolve, reject) => {
    chrome.devtools.inspectedWindow.eval(expression, (result, exception) => {
      if (exception?.isError || exception?.isException) {
        reject(new Error(String(exception.value ?? exception.description)));
      } else {
        resolve(result as T);
      }
    });
  });
}

// Whether Mayu has registered with the hook in the page.
export function isDetected() {
  return evalInPage<boolean>(`Boolean(${HOOK}?.detected())`);
}

// The vnode id of the element selected in the Elements panel.
export function selectedId() {
  return evalInPage<string | null>(`${HOOK}?.idForNode($0) ?? null`);
}

// Highlights the DOM nodes with the vnode ids in the page.
export function highlight(ids: string[], label: string) {
  return evalInPage<void>(
    `${HOOK}?.highlight(${JSON.stringify(ids)}, ${JSON.stringify(label)})`,
  );
}

export function hideHighlight() {
  return evalInPage<void>(`${HOOK}?.hideHighlight()`);
}

// Selects the DOM node with the vnode id in the Elements panel.
export function reveal(id: string) {
  const node = `${HOOK}?.node(${JSON.stringify(id)})`;
  return evalInPage<boolean>(`${node} ? (inspect(${node}), true) : false`);
}
