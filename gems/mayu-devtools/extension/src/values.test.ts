import { describe, expect, it } from "vitest";

import { summary, toPlain, type Entry } from "./values";

describe("summary", () => {
  it("writes values the way Ruby would", () => {
    expect(summary({ kind: "nil" })).toBe("nil");
    expect(summary({ kind: "symbol", value: "open" })).toBe(":open");
    expect(summary({ kind: "string", value: "hi", truncated: true })).toBe(
      '"hi"…',
    );
    expect(
      summary({ kind: "collection", class: "Array", size: 3, entries: [] }),
    ).toBe("Array(3)");
    expect(summary({ kind: "object", class: "User" })).toBe("#<User>");
  });
});

describe("toPlain", () => {
  it("turns entries into a plain object", () => {
    const entries: Entry[] = [
      { key: "$title", value: { kind: "string", value: "Hi" } },
      {
        key: "@items",
        value: {
          kind: "collection",
          class: "Array",
          size: 1,
          entries: [{ key: "0", value: { kind: "number", value: 1 } }],
        },
      },
      { key: "@callback", value: { kind: "function", value: "go" } },
    ];

    expect(toPlain(entries)).toEqual({
      $title: "Hi",
      "@items": { 0: 1 },
      "@callback": "ƒ go",
    });
  });
});
