// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { useState } from "preact/hooks";

import { summary, type Entry } from "../values";

// Ruby values as a tree that expands like the console's object view.
export default function Entries({ entries }: { entries: Entry[] }) {
  return (
    <ul class="entries">
      {entries.map((entry) => (
        <EntryRow key={entry.key} entry={entry} />
      ))}
    </ul>
  );
}

function EntryRow({ entry }: { entry: Entry }) {
  const [open, setOpen] = useState(false);
  const children = entry.value.entries ?? [];
  const expandable = children.length > 0;

  return (
    <li>
      <div
        class={`entry ${expandable ? "expandable" : ""}`}
        onClick={() => expandable && setOpen(!open)}
      >
        <span class="toggle">{expandable ? (open ? "▾" : "▸") : ""}</span>
        <span class="key">{entry.key}</span>
        <span class={`value ${entry.value.kind}`}>{summary(entry.value)}</span>
      </div>
      {open && <Entries entries={children} />}
    </li>
  );
}
