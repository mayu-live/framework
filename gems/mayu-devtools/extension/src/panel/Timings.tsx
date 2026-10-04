// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { useCallback, useEffect, useState } from "preact/hooks";

import type Connection from "../connection";

// The answer to a "timings" query. See
// gems/mayu-devtools/lib/mayu/devtools/inspector.rb.
type TimingRow = {
  name: string;
  count: number;
  totalMs: number;
  maxMs: number;
  lastMs: number;
};

type TimingsAnswer = {
  since: number;
  renders: TimingRow[];
  reconciles: TimingRow[];
  callbacks: TimingRow[];
};

function isTimings(value: unknown): value is TimingsAnswer {
  return (
    typeof value === "object" &&
    value !== null &&
    Array.isArray((value as TimingsAnswer).renders)
  );
}

// Render and callback timings, fetched again after each batch. The server
// starts recording when this tab first asks.
export default function Timings({ connection }: { connection: Connection }) {
  const [timings, setTimings] = useState<TimingsAnswer | null>(null);

  const load = useCallback(
    async (reset = false) => {
      const answer = await connection
        .inspect({ type: "timings", reset })
        .catch(() => null);
      if (isTimings(answer)) setTimings(answer);
    },
    [connection],
  );

  useEffect(() => {
    void load();
    return connection.subscribe((message) => {
      if (message.type === "batch") void load();
    });
  }, [connection, load]);

  if (!timings) return <p class="status">Loading…</p>;

  return (
    <div class="timings">
      <p class="status">
        Recording since {new Date(timings.since).toLocaleTimeString()}, per
        component class.{" "}
        <button type="button" onClick={() => void load(true)}>
          Reset
        </button>
      </p>
      <TimingTable title="Renders" rows={timings.renders} />
      <TimingTable title="Updates" rows={timings.reconciles} />
      <TimingTable title="Callbacks" rows={timings.callbacks} />
    </div>
  );
}

type SortKey = keyof TimingRow;

const COLUMNS: [SortKey, string][] = [
  ["name", "Name"],
  ["count", "Count"],
  ["totalMs", "Total ms"],
  ["maxMs", "Max ms"],
  ["lastMs", "Last ms"],
];

function TimingTable({ title, rows }: { title: string; rows: TimingRow[] }) {
  const [sortKey, setSortKey] = useState<SortKey>("totalMs");

  if (rows.length === 0) return null;

  const sorted = [...rows].sort((a, b) =>
    sortKey === "name"
      ? a.name.localeCompare(b.name)
      : (b[sortKey] as number) - (a[sortKey] as number),
  );

  return (
    <section class="values">
      <h2>{title}</h2>
      <table class="timing-table">
        <thead>
          <tr>
            {COLUMNS.map(([key, label]) => (
              <th
                key={key}
                class={key === sortKey ? "sorted" : ""}
                onClick={() => setSortKey(key)}
              >
                {label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {sorted.map((row) => (
            <tr key={row.name}>
              <td>{row.name}</td>
              <td class="number">{row.count}</td>
              <td class="number">{row.totalMs.toFixed(2)}</td>
              <td class="number">{row.maxMs.toFixed(2)}</td>
              <td class="number">{row.lastMs.toFixed(2)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
