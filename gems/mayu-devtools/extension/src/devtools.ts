// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// The devtools page: adds the Mayu panel, and a Mayu pane to the Elements
// panel's sidebar showing which components render the selected element.

import Connection from "./connection";
import { isDetected, selectedId } from "./page";
import { isTree, ownerComponents, type TreeNode } from "./tree";

chrome.devtools.panels.create("Mayu", "icon.svg", "panel.html");

const connection = new Connection();

function label(component: TreeNode) {
  return component.path
    ? `${component.name} (${component.path})`
    : component.name;
}

async function describeSelection(): Promise<Record<string, unknown>> {
  if (!(await isDetected())) return { status: "Mayu not detected" };

  const id = await selectedId();
  if (!id) return { status: "Not rendered by Mayu" };

  const tree = await connection.inspect({ type: "tree" });
  if (tree === null || tree === undefined) {
    return { status: "Devtools are not enabled on the server" };
  }
  if (!isTree(tree)) return { status: "Unexpected answer", answer: tree };

  const [component, ...ancestors] = ownerComponents(tree, id);
  if (!component) return { status: "Not rendered by a component" };

  return {
    component: component.name,
    path: component.path ?? null,
    id: component.id,
    ancestors: ancestors.map(label),
  };
}

chrome.devtools.panels.elements.createSidebarPane("Mayu", (sidebar) => {
  let generation = 0;

  const update = async () => {
    const current = ++generation;
    let content: Record<string, unknown>;
    try {
      content = await describeSelection();
    } catch (error) {
      content = { status: String(error) };
    }
    // A newer selection may have been described first.
    if (current === generation) sidebar.setObject(content, "Component");
  };

  chrome.devtools.panels.elements.onSelectionChanged.addListener(update);
  connection.subscribe((message) => {
    if (message.type === "detected") void update();
  });
  void update();
});
