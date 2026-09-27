// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Ruby values as the server's formatter sends them. See
// gems/mayu-devtools/lib/mayu/devtools/formatter.rb.
export type Value = {
  kind:
    | "nil"
    | "boolean"
    | "number"
    | "string"
    | "symbol"
    | "function"
    | "class"
    | "component"
    | "collection"
    | "object"
    | "cycle";
  class?: string;
  value?: string | number | boolean;
  size?: number;
  entries?: Entry[];
  truncated?: boolean;
};

export type Entry = { key: string; value: Value };

// The answer to a "details" query.
export type Details =
  | {
      id: string;
      type: "component";
      props: Entry[];
      state: Entry[];
      instanceVariables: Entry[];
      context: Entry[];
    }
  | { id: string; type: "element"; attributes: Entry[] }
  | { id: string; type: "other" };

export function isDetails(value: unknown): value is Details {
  return (
    typeof value === "object" &&
    value !== null &&
    typeof (value as Details).id === "string" &&
    typeof (value as Details).type === "string"
  );
}

// A value on one line, written the way Ruby would.
export function summary(value: Value): string {
  const more = value.truncated ? "…" : "";

  switch (value.kind) {
    case "nil":
      return "nil";
    case "boolean":
    case "number":
      return String(value.value);
    case "string":
      return `${JSON.stringify(value.value)}${more}`;
    case "symbol":
      return `:${value.value}`;
    case "function":
      return `ƒ ${value.value}`;
    case "class":
    case "component":
      return String(value.value);
    case "cycle":
      return `${value.class} (cycle)`;
    case "collection":
      return `${value.class}(${value.size})`;
    case "object":
      return `#<${value.class}${more}>`;
  }
}

// Entries as a plain object, for the Elements sidebar pane, which shows
// objects itself.
export function toPlain(entries: Entry[]): Record<string, unknown> {
  return Object.fromEntries(
    entries.map((entry) => [entry.key, plainValue(entry.value)]),
  );
}

function plainValue(value: Value): unknown {
  switch (value.kind) {
    case "nil":
      return null;
    case "boolean":
    case "number":
      return value.value;
    case "string":
      return `${value.value}${value.truncated ? "…" : ""}`;
    case "collection":
    case "object":
      return value.entries ? toPlain(value.entries) : summary(value);
    default:
      return summary(value);
  }
}
