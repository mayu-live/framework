import { afterEach, describe, expect, it, vi } from "vitest";

import "./mayu-ping";

function mount(attributes = "") {
  document.body.innerHTML = `<mayu-ping ${attributes}></mayu-ping>`;
  const ping = document.querySelector("mayu-ping")!;
  const root = ping.shadowRoot!;
  return {
    ping,
    badge: root.getElementById("badge")!,
    progress: root.querySelector("mayu-navigation-progress")!.shadowRoot!,
    dialog: root.querySelector("mayu-connection-dialog")!.shadowRoot!,
  };
}

afterEach(() => {
  document.body.innerHTML = "";
  vi.useRealTimers();
});

describe("mayu-ping", () => {
  it("shows the ping in its badge", () => {
    const { ping, badge } = mount('ping="N/A"');
    expect(badge.textContent).toBe("N/A");

    ping.setAttribute("ping", "12ms");
    expect(badge.textContent).toBe("12ms");
  });

  it("applies the attributes it was rendered with", () => {
    const { dialog, progress } = mount(
      'status="disconnected" navigation="pending" reconnect-attempt="3"',
    );

    expect(dialog.querySelector("dialog")!.open).toBe(true);
    expect(dialog.getElementById("attempt")!.textContent).toBe(
      "Attempt 3 · connecting…",
    );
    expect(progress.getElementById("bar")!.hasAttribute("data-shown")).toBe(
      true,
    );
  });
});

describe("mayu-ping navigation progress", () => {
  it("shows a manual popover while a navigation is pending", () => {
    vi.useFakeTimers();
    const { ping, progress } = mount();
    const bar = progress.getElementById("bar")!;
    const shown = () => bar.hasAttribute("data-shown");

    expect(bar.getAttribute("popover")).toBe("manual");
    expect(shown()).toBe(false);

    ping.setAttribute("navigation", "pending");
    expect(shown()).toBe(true);

    // The bar fills up before it goes away.
    ping.setAttribute("navigation", "complete");
    expect(shown()).toBe(true);
    expect(bar.classList.contains("is-complete")).toBe(true);

    vi.advanceTimersByTime(180);
    expect(shown()).toBe(false);
    expect(bar.classList.contains("is-complete")).toBe(false);
  });

  it("hides the bar at once when the navigation is dropped", () => {
    const { ping, progress } = mount('navigation="pending"');
    const bar = progress.getElementById("bar")!;

    ping.removeAttribute("navigation");

    expect(bar.hasAttribute("data-shown")).toBe(false);
  });
});

describe("mayu-ping connection dialog", () => {
  it("covers the page while there is no connection", () => {
    vi.useFakeTimers();
    const { ping, dialog } = mount('status="connected"');
    const element = dialog.querySelector("dialog")!;

    expect(element.open).toBe(false);

    ping.setAttribute("status", "disconnected");
    expect(element.open).toBe(true);
    expect(dialog.getElementById("title")!.textContent).toBe("Disconnected");

    ping.setAttribute("status", "transferring");
    expect(element.open).toBe(true);
    expect(dialog.getElementById("title")!.textContent).toBe("Transferring");

    // It closes once its transition out has run.
    ping.setAttribute("status", "connected");
    expect(element.open).toBe(true);
    vi.advanceTimersByTime(200);
    expect(element.open).toBe(false);
  });

  it("stays open when the connection drops again while it is closing", () => {
    vi.useFakeTimers();
    const { ping, dialog } = mount('status="disconnected"');

    ping.setAttribute("status", "connected");
    vi.advanceTimersByTime(100);
    ping.setAttribute("status", "disconnected");
    vi.advanceTimersByTime(500);

    expect(dialog.querySelector("dialog")!.open).toBe(true);
  });

  it("opens again after the element has been moved", () => {
    const { ping, dialog } = mount('status="disconnected"');
    const element = dialog.querySelector("dialog")!;

    ping.remove();
    expect(element.open).toBe(false);

    document.body.append(ping);
    expect(element.open).toBe(true);
  });

  it("shows the attempt and counts down to the next one", () => {
    vi.useFakeTimers({ now: 10_000 });
    const { ping, dialog } = mount();
    const attempt = dialog.getElementById("attempt")!;
    const countdown = dialog.getElementById("countdown")!;
    const seconds = dialog.getElementById("seconds")!;

    expect(attempt.hidden).toBe(true);
    expect(countdown.hidden).toBe(true);

    ping.setAttribute("reconnect-attempt", "2");
    expect(attempt.hidden).toBe(false);
    expect(attempt.textContent).toBe("Attempt 2 · connecting…");
    expect(seconds.textContent).toBe("");
    expect(countdown.classList.contains("is-connecting")).toBe(true);

    ping.setAttribute("reconnect-at", "13000");
    expect(attempt.textContent).toBe("Attempt 2 failed");
    expect(seconds.textContent).toBe("3s");
    expect(countdown.classList.contains("is-waiting")).toBe(true);
    expect(countdown.style.getPropertyValue("--retry-duration")).toBe("3000ms");

    vi.advanceTimersByTime(1_000);
    expect(seconds.textContent).toBe("2s");

    ping.removeAttribute("reconnect-at");
    ping.removeAttribute("reconnect-attempt");
    expect(attempt.hidden).toBe(true);
    expect(countdown.hidden).toBe(true);
  });
});
