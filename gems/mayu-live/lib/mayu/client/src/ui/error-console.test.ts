import { afterEach, expect, it, vi } from "vitest";

import { logToConsole } from "./error-console";
import { buildReport } from "./error-report";

afterEach(() => vi.restoreAllMocks());

it("logs the error with the source around it and one style per line", () => {
  const log = vi.spyOn(console, "error").mockImplementation(() => {});
  const source = Array.from({ length: 12 }, (_, i) => `line ${i + 1}`);

  logToConsole(
    buildReport({
      file: "app:/pages/+page.haml",
      type: "RuntimeError",
      message: "boom",
      backtrace: ["app:/pages/+page.haml:8:in 'render'"],
      source: source.join("\n") + "\n",
      treePath: [
        { name: "body" },
        { name: "Page", path: "app:/pages/+page.haml" },
      ],
      line: null,
      column: null,
      hints: ["Try something else"],
    }),
  );

  const [text, ...styles] = log.mock.calls[0];
  const lines = (text as string).split("\n");

  expect(lines).toEqual([
    "%cRuntimeError: boom",
    "%capp:/pages/+page.haml",
    "%cTry something else",
    "%c%body",
    "%c  %Page (app:/pages/+page.haml)",
    "%c   6 | line 6",
    "%c   7 | line 7",
    "%c>  8 | line 8",
    "%c   9 | line 9",
    "%c  10 | line 10",
    "%c  11 | line 11",
    "%capp:/pages/+page.haml:8:in 'render'",
  ]);
  expect(styles).toHaveLength(lines.length);
});
