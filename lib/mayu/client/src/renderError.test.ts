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
      [{ name: "Page", path: "/app/pages/demos/exceptions/+page.haml" }]
    );

    const exception = document.querySelector("mayu-exception");
    expect(exception).not.toBeNull();
    expect(exception?.textContent).toContain("NoMatchingPatternError");
    expect(exception?.textContent).toContain("The callback failed");
    expect(exception?.textContent).toContain("%Page");
  });
});
