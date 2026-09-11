import { afterEach, describe, expect, it, vi } from "vitest";

import renderError from "./renderError";

describe("renderError", () => {
  afterEach(() => {
    document.querySelectorAll("mayu-exception").forEach((element) => {
      element.remove();
    });
    vi.restoreAllMocks();
  });

  it("renders listener errors without source code", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    renderError(
      "/app/pages/demos/exceptions/+page.haml",
      "NoMatchingPatternError",
      "The callback failed",
      ["/app/pages/demos/exceptions/+page.haml:13:in 'handle_click'"],
      null,
      [{ name: "Page", path: "/app/pages/demos/exceptions/+page.haml" }],
    );

    const exception = document.querySelector("mayu-exception");
    expect(exception).not.toBeNull();
    expect(exception?.textContent).toContain("NoMatchingPatternError");
    expect(exception?.textContent).toContain("The callback failed");
    expect(exception?.textContent).toContain("%Page");
  });

  it("highlights the source line named by a module id backtrace frame", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    renderError(
      "app:/CustomElement.tsx",
      "SyntaxError",
      "Expected an element",
      ["app:/CustomElement.tsx:2:24", "app:/other.tsx:9"],
      "const a = 1;\nconst b = 2;\nconst c = 3;\n",
      [],
    );

    const lines = document.querySelectorAll("mayu-exception li.source-line");
    const highlighted = document.querySelectorAll(
      "mayu-exception li.source-line.is-interesting",
    );

    expect(lines).toHaveLength(4);
    expect(highlighted).toHaveLength(1);
    expect(highlighted[0]?.textContent).toContain("const b = 2;");
  });
});
