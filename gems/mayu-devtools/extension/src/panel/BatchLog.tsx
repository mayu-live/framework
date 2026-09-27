// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { commandSummary, type BatchEntry } from "../batch";

// The batches the page applied, newest first.
export default function BatchLog({ entries }: { entries: BatchEntry[] }) {
  if (entries.length === 0) {
    return <p class="status">No batches yet.</p>;
  }

  return (
    <table class="batch-log">
      <thead>
        <tr>
          <th>Time</th>
          <th>Applied in</th>
          <th>Commands</th>
          <th>Nodes</th>
        </tr>
      </thead>
      <tbody>
        {entries.map((entry, index) => (
          <tr key={`${entry.at}:${index}`}>
            <td>{time(entry.at)}</td>
            <td class="number">{entry.durationMs.toFixed(1)} ms</td>
            <td>{commandSummary(entry.commands)}</td>
            <td class="number" title={entry.ids.join(" ")}>
              {entry.ids.length}
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function time(at: number) {
  const date = new Date(at);
  const ms = String(date.getMilliseconds()).padStart(3, "0");
  return `${date.toLocaleTimeString([], { hour12: false })}.${ms}`;
}
