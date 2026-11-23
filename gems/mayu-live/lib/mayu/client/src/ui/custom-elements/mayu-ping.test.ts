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

describe("mayu-ping reconnect status", () => {
  afterEach(() => {
    document.body.innerHTML = "";
    vi.useRealTimers();
  });

  it("shows the attempt and counts down to the next one", () => {
    vi.useFakeTimers({ now: 10_000 });
    document.body.innerHTML = "<mayu-ping></mayu-ping>";
    const ping = document.querySelector("mayu-ping")!;
    const status = ping.shadowRoot!.querySelector(
      ".reconnect-status",
    ) as HTMLParagraphElement;
    const countdown = ping.shadowRoot!.querySelector(
      ".reconnect-countdown",
    ) as HTMLDivElement;
    const seconds = ping.shadowRoot!.querySelector(
      ".reconnect-seconds",
    ) as HTMLSpanElement;

    expect(status.hidden).toBe(true);
    expect(countdown.hidden).toBe(true);

    ping.setAttribute("reconnect-attempt", "2");
    expect(status.hidden).toBe(false);
    expect(status.textContent).toBe("Attempt 2 · connecting…");
    expect(seconds.textContent).toBe("");
    expect(countdown.classList.contains("is-connecting")).toBe(true);

    ping.setAttribute("reconnect-at", "13000");
    expect(status.textContent).toBe("Attempt 2 failed");
    expect(seconds.textContent).toBe("3s");
    expect(countdown.classList.contains("is-waiting")).toBe(true);
    expect(countdown.style.getPropertyValue("--retry-duration")).toBe("3000ms");

    vi.advanceTimersByTime(1_000);
    expect(seconds.textContent).toBe("2s");

    ping.removeAttribute("reconnect-at");
    ping.removeAttribute("reconnect-attempt");
    expect(status.hidden).toBe(true);
    expect(countdown.hidden).toBe(true);
  });
});
