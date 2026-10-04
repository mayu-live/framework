import { describe, expect, it } from "vitest";

import { commandSummary, summarizeBatch } from "./batch";

describe("summarizeBatch", () => {
  it("counts commands and collects the nodes they change", () => {
    const entry = summarizeBatch(
      [
        ["SetTextContent", "v7", "hi"],
        ["AddClass", "v5", ["open"]],
        ["AddClass", "v5", ["shown"]],
        ["Pong", 12],
      ],
      1.5,
      1000,
    );

    expect(entry).toEqual({
      at: 1000,
      durationMs: 1.5,
      commands: { SetTextContent: 1, AddClass: 2, Pong: 1 },
      ids: ["v7", "v5"],
    });
  });

  it("collects every node of created trees", () => {
    const entry = summarizeBatch(
      [
        [
          "CreateTree",
          "<li><b>new</b></li>",
          [{ id: "v9", name: "LI", children: [{ id: "va", name: "B" }] }],
        ],
      ],
      1,
      0,
    );

    expect(entry.ids).toEqual(["v9", "va"]);
  });

  it("looks inside view transitions", () => {
    const entry = summarizeBatch(
      [["ViewTransition", [["RemoveNode", "v3"]], [], null]],
      1,
      0,
    );

    expect(entry.commands).toEqual({ ViewTransition: 1, RemoveNode: 1 });
    expect(entry.ids).toEqual(["v3"]);
  });
});

describe("commandSummary", () => {
  it("lists the most frequent commands first", () => {
    expect(commandSummary({ SetCSSProperty: 1, AddClass: 2 })).toBe(
      "AddClass ×2, SetCSSProperty",
    );
  });
});
