import { afterEach, describe, expect, it, vi } from "vitest";

import "./mayu-ping";

describe("mayu-ping navigation progress", () => {
  afterEach(() => {
    document.body.innerHTML = "";
    vi.restoreAllMocks();
  });

  it("uses a manual popover for the navigation progress bar", () => {
    const showPopover = vi.fn();
    const hidePopover = vi.fn();
    document.body.innerHTML = "<mayu-ping></mayu-ping>";
    const ping = document.querySelector("mayu-ping")!;
    const progress = ping.shadowRoot!.querySelector(
      ".navigation-progress",
    ) as HTMLDivElement;
    Object.defineProperty(progress, "showPopover", { value: showPopover });
    Object.defineProperty(progress, "hidePopover", { value: hidePopover });
    vi.spyOn(progress, "matches").mockReturnValue(false);

    ping.setAttribute("navigation", "pending");
    expect(progress.getAttribute("popover")).toBe("manual");
    expect(showPopover).toHaveBeenCalledOnce();

    ping.removeAttribute("navigation");
    expect(hidePopover).toHaveBeenCalledOnce();
  });
});
