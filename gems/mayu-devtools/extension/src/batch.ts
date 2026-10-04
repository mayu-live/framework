// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import type {
  Batch,
  Command,
} from "../../../mayu-live/lib/mayu/client/src/protocol";

// A batch the page applied, as the Batches tab lists it. Only command names
// and node ids leave the page, not the commands' arguments.
export type BatchEntry = {
  at: number;
  durationMs: number;
  commands: Record<string, number>;
  ids: string[];
};

// Commands whose first argument is the id of the DOM node they change. See
// gems/mayu-live/lib/mayu/runtime/commands.rb.
const NODE_COMMANDS = new Set([
  "CreateElement",
  "CreateTextNode",
  "CreateComment",
  "ReplaceChildren",
  "RemoveNode",
  "SetAttribute",
  "RemoveAttribute",
  "SetClassName",
  "AddClass",
  "RemoveClass",
  "SetListener",
  "RemoveListener",
  "SetCSSProperty",
  "RemoveCSSProperty",
  "SetTextContent",
  "ReplaceData",
  "InsertData",
  "DeleteData",
]);

type IdNode = { id: string; children?: IdNode[] };

export function summarizeBatch(
  batch: Batch,
  durationMs: number,
  at: number,
): BatchEntry {
  const commands: Record<string, number> = {};
  const ids = new Set<string>();
  collect(batch, commands, ids);
  return { at, durationMs, commands, ids: [...ids] };
}

function collect(
  batch: Batch,
  commands: Record<string, number>,
  ids: Set<string>,
) {
  for (const [name, ...args] of batch as Command[]) {
    commands[name] = (commands[name] ?? 0) + 1;

    if (NODE_COMMANDS.has(name)) {
      if (typeof args[0] === "string") ids.add(args[0]);
    } else if (name === "CreateTree") {
      collectTree(args[1] as IdNode | IdNode[] | undefined, ids);
    } else if (name === "ViewTransition") {
      collect(args[0] as Batch, commands, ids);
    }
  }
}

function collectTree(tree: IdNode | IdNode[] | undefined, ids: Set<string>) {
  if (!tree) return;

  for (const node of Array.isArray(tree) ? tree : [tree]) {
    ids.add(node.id);
    collectTree(node.children, ids);
  }
}

// The most frequent commands first: `AddClass ×2, SetCSSProperty`.
export function commandSummary(commands: Record<string, number>) {
  return Object.entries(commands)
    .sort(([, a], [, b]) => b - a)
    .map(([name, count]) => (count > 1 ? `${name} ×${count}` : name))
    .join(", ");
}
