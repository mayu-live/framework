import { afterEach, describe, expect, it, vi } from "vitest";

import { createBrowserActionHandler } from "./browser-actions";

describe("browser actions", () => {
  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it("navigates with a new history entry by default", () => {
    const navigator = { navigate: vi.fn() };
    const handle = createBrowserActionHandler(navigator);

    handle("navigate", ["?page=2", false]);

    expect(navigator.navigate).toHaveBeenCalledWith("?page=2", true);
  });

  it("replaces the history entry when asked to", () => {
    const navigator = { navigate: vi.fn() };
    const handle = createBrowserActionHandler(navigator);

    handle("navigate", ["?per_page=40", true]);

    expect(navigator.navigate).toHaveBeenCalledWith("?per_page=40", false);
  });

  it("shows an alert after the next frame", () => {
    vi.useFakeTimers();
    vi.stubGlobal("requestAnimationFrame", (callback: () => void) =>
      setTimeout(callback, 0),
    );
    const alert = vi.spyOn(window, "alert").mockImplementation(() => {});
    const handle = createBrowserActionHandler({ navigate: vi.fn() });

    handle("alert", ["Hello"]);
    expect(alert).not.toHaveBeenCalled();

    vi.runAllTimers();
    expect(alert).toHaveBeenCalledWith("Hello");
  });

  it("warns about unknown actions", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    const handle = createBrowserActionHandler({ navigate: vi.fn() });

    handle("teleport", []);

    expect(warn).toHaveBeenCalledWith("Unknown browser action: teleport");
  });
});
