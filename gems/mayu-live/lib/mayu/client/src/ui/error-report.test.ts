import { describe, expect, it } from "vitest";

import { buildReport, fromCommand, type RenderErrorInfo } from "./error-report";

function error(overrides: Partial<RenderErrorInfo>): RenderErrorInfo {
  return {
    file: "app:/pages/+page.haml",
    type: "RuntimeError",
    message: "boom",
    backtrace: [],
    source: null,
    treePath: [],
    line: null,
    column: null,
    hints: [],
    ...overrides,
  };
}

describe("fromCommand", () => {
  it("names the arguments of a RenderError command", () => {
    expect(
      fromCommand([
        "app:/a.haml",
        "NameError",
        "nope",
        ["app:/a.haml:1"],
        "%p\n",
        [{ name: "Page", path: "app:/a.haml" }],
        1,
        2,
        ["a hint"],
      ]),
    ).toEqual({
      file: "app:/a.haml",
      type: "NameError",
      message: "nope",
      backtrace: ["app:/a.haml:1"],
      source: "%p\n",
      treePath: [{ name: "Page", path: "app:/a.haml" }],
      line: 1,
      column: 2,
      hints: ["a hint"],
    });
  });
});

describe("buildReport", () => {
  it("adds the line and column to the location when the error has them", () => {
    expect(buildReport(error({})).location).toBe("app:/pages/+page.haml");
    expect(buildReport(error({ line: 2 })).location).toBe(
      "app:/pages/+page.haml:2",
    );
    expect(buildReport(error({ line: 2, column: 7 })).location).toBe(
      "app:/pages/+page.haml:2:7",
    );
  });

  it("marks the source lines that the backtrace names in this file", () => {
    const report = buildReport(
      error({
        file: "app:/CustomElement.tsx",
        backtrace: ["app:/CustomElement.tsx:2:24", "app:/other.tsx:3"],
        source: "const a = 1;\nconst b = 2;\nconst c = 3;\n",
      }),
    );

    expect(report.source).toEqual([
      { number: 1, text: "const a = 1;", marked: false, caret: null },
      { number: 2, text: "const b = 2;", marked: true, caret: null },
      { number: 3, text: "const c = 3;", marked: false, caret: null },
    ]);
  });

  it("marks the line a build error reports, with its column", () => {
    const report = buildReport(
      error({ source: "import a;\nimport b;\n", line: 2, column: 8 }),
    );

    expect(report.source.map((line) => [line.marked, line.caret])).toEqual([
      [false, null],
      [true, 8],
    ]);
  });

  it("has no source lines without source", () => {
    expect(buildReport(error({ line: 2 })).source).toEqual([]);
  });

  it("tells the module's frames, the app's and the framework's apart", () => {
    const report = buildReport(
      error({
        backtrace: [
          "app:/pages/+page.haml:2:in 'render'",
          "app:/components/Card.haml:9:in 'render'",
          "mayu-live/lib/mayu/runtime/vnodes/vcomponent.rb:1:in 'update'",
          "<internal:kernel>:187:in 'Kernel#loop'",
          "not a frame",
        ],
      }),
    );

    expect(report.backtrace.map((frame) => frame.kind)).toEqual([
      "module",
      "app",
      "framework",
      "framework",
      "framework",
    ]);
  });

  it("puts each component from a module on a line and groups the rest", () => {
    const report = buildReport(
      error({
        treePath: [
          { name: "html" },
          { name: "body" },
          { name: "Layout", path: "app:/pages/+layout.haml" },
          { name: "main" },
          { name: "Slot", path: "(internal)::Slot" },
          { name: "Page", path: "app:/pages/+page.haml" },
        ],
      }),
    );

    expect(report.tree).toEqual([
      [
        { name: "html", path: null },
        { name: "body", path: null },
      ],
      [{ name: "Layout", path: "app:/pages/+layout.haml" }],
      [
        { name: "main", path: null },
        { name: "Slot", path: null },
      ],
      [{ name: "Page", path: "app:/pages/+page.haml" }],
    ]);
  });
});
