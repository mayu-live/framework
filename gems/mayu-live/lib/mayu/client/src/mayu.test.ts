import { afterEach, describe, expect, it, vi } from "vitest";

import Mayu from "./mayu";
import type { ClientEvent } from "./protocol";

class FakeNavigation extends EventTarget {
  navigate = vi.fn();
}

function navigationEvent(overrides: Partial<Record<string, unknown>> = {}) {
  const event = new Event("navigate") as Event & Record<string, unknown>;
  Object.assign(event, {
    canIntercept: true,
    destination: { url: new URL("/next?tab=details", location.origin).href },
    downloadRequest: null,
    formData: null,
    hashChange: false,
    navigationType: "push",
    intercept: vi.fn(),
    ...overrides,
  });
  return event;
}

describe("Mayu callbacks", () => {
  afterEach(() => {
    document.body.innerHTML = "";
    vi.useRealTimers();
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it("drops events explicitly when no callback transport is active", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const mayu = new Mayu({ autoPing: false });
    const button = document.createElement("button");
    button.addEventListener("click", (event) =>
      mayu.callback(event, "listener"),
    );
    document.body.append(button);

    button.dispatchEvent(new MouseEvent("click", { cancelable: true }));

    expect(warn).toHaveBeenCalledWith(
      "Dropping callback: callback transport unavailable",
    );
    mayu.dispose();
  });

  it("prevents the default action of handled events", () => {
    const mayu = new Mayu({ autoPing: false });
    mayu.setWriter({ write: vi.fn(async () => undefined) } as any);
    const button = document.createElement("button");
    button.addEventListener("click", (event) =>
      mayu.callback(event, "listener"),
    );
    document.body.append(button);

    const event = new MouseEvent("click", { cancelable: true });
    button.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(true);
    mayu.dispose();
  });

  it("lets popover invoker buttons keep their default action", () => {
    const mayu = new Mayu({ autoPing: false });
    mayu.setWriter({ write: vi.fn(async () => undefined) } as any);
    const button = document.createElement("button");
    button.setAttribute("popovertarget", "menu");
    button.addEventListener("click", (event) =>
      mayu.callback(event, "listener"),
    );
    document.body.append(button);

    const event = new MouseEvent("click", { cancelable: true });
    button.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(false);
    mayu.dispose();
  });

  it("does not throttle discrete events", async () => {
    const mayu = new Mayu({ autoPing: false });
    const write = vi.fn(async (_message: ClientEvent) => undefined);
    mayu.setWriter({ write } as any);
    const button = document.createElement("button");
    button.addEventListener("click", (event) =>
      mayu.callback(event, "listener"),
    );
    document.body.append(button);

    button.click();
    button.click();
    await Promise.resolve();

    expect(write).toHaveBeenCalledTimes(2);
    mayu.dispose();
  });

  it("sends Backspace keydown callbacks", async () => {
    const mayu = new Mayu({ autoPing: false });
    const write = vi.fn(async (_message: ClientEvent) => undefined);
    mayu.setWriter({ write } as any);
    const calculator = document.createElement("div");
    calculator.addEventListener("keydown", (event) =>
      mayu.callback(event, "listener"),
    );
    document.body.append(calculator);

    calculator.dispatchEvent(
      new KeyboardEvent("keydown", { cancelable: true, key: "Backspace" }),
    );
    await Promise.resolve();

    expect(write).toHaveBeenCalledWith(
      expect.arrayContaining([
        "Callback",
        "listener",
        expect.objectContaining({ eventType: "keydown", key: "Backspace" }),
      ]),
    );
    mayu.dispose();
  });

  it("coalesces continuous events by event type and listener", async () => {
    vi.useFakeTimers();
    const mayu = new Mayu({ autoPing: false });
    const write = vi.fn(async (_message: ClientEvent) => undefined);
    mayu.setWriter({ write } as any);
    const input = document.createElement("input");
    input.addEventListener("input", (event) =>
      mayu.callback(event, "listener"),
    );
    document.body.append(input);

    input.value = "a";
    input.dispatchEvent(new InputEvent("input"));
    input.value = "ab";
    input.dispatchEvent(new InputEvent("input"));
    input.value = "abc";
    input.dispatchEvent(new InputEvent("input"));
    await vi.runAllTimersAsync();

    expect(write).toHaveBeenCalledTimes(2);
    const message = write.mock.calls[1]?.[0];
    expect((message?.[2] as any).target.value).toBe("abc");
    mayu.dispose();
  });
});

describe("Mayu navigation", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it("intercepts same-origin navigations and sends their path and query", async () => {
    const navigation = new FakeNavigation();
    vi.stubGlobal("navigation", navigation);
    const write = vi.fn(async () => undefined);
    const mayu = new Mayu({ autoPing: false });
    mayu.setWriter({ write } as any);
    const event = navigationEvent();

    navigation.dispatchEvent(event);
    const intercept = event.intercept as ReturnType<typeof vi.fn>;
    expect(intercept).toHaveBeenCalledTimes(1);
    await intercept.mock.calls[0][0].handler();

    expect(write).toHaveBeenCalledWith([
      "Navigate",
      "/next?tab=details",
      expect.any(Number),
    ]);
    mayu.dispose();
  });

  it.each([
    ["a hash change", { hashChange: true }],
    ["a download", { downloadRequest: "file" }],
    ["a form submission", { formData: new FormData() }],
    ["a reload", { navigationType: "reload" }],
    [
      "a cross-origin destination",
      { destination: { url: "https://example.com/next" } },
    ],
  ])("does not intercept %s", (_name, overrides) => {
    const navigation = new FakeNavigation();
    vi.stubGlobal("navigation", navigation);
    const mayu = new Mayu({ autoPing: false });
    mayu.setWriter({ write: vi.fn(async () => undefined) } as any);
    const event = navigationEvent(overrides);

    navigation.dispatchEvent(event);

    expect(event.intercept).not.toHaveBeenCalled();
    mayu.dispose();
  });

  it("uses the native Navigation API for programmatic navigation", () => {
    const navigation = new FakeNavigation();
    vi.stubGlobal("navigation", navigation);
    const mayu = new Mayu({ autoPing: false });

    mayu.navigate("/next");
    mayu.navigate("/current", false);

    expect(navigation.navigate).toHaveBeenNthCalledWith(1, "/next", {
      history: "push",
    });
    expect(navigation.navigate).toHaveBeenNthCalledWith(2, "/current", {
      history: "replace",
    });
    mayu.dispose();
  });
});

describe("Mayu pings", () => {
  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  class FakeWorker {
    static instances: FakeWorker[] = [];
    onmessage: ((event: MessageEvent) => void) | null = null;
    terminated = false;
    messages: unknown[] = [];
    constructor(public url: string) {
      FakeWorker.instances.push(this);
    }
    terminate() {
      this.terminated = true;
    }
    postMessage(message: unknown) {
      this.messages.push(message);
    }
  }

  function stubWorker() {
    FakeWorker.instances = [];
    vi.stubGlobal("Worker", FakeWorker);
    vi.stubGlobal("URL", {
      ...URL,
      createObjectURL: vi.fn(() => "blob:ticker"),
      revokeObjectURL: vi.fn(),
    });
  }

  it("schedules an idle ping with a worker", async () => {
    stubWorker();
    const write = vi.fn(async () => undefined);
    const mayu = new Mayu();
    mayu.setWriter({ write } as any);

    expect(FakeWorker.instances).toHaveLength(1);
    expect(FakeWorker.instances[0].messages).toEqual([4_000]);
    FakeWorker.instances[0].onmessage!(new MessageEvent("message"));
    await Promise.resolve();

    expect(write).toHaveBeenCalledWith(["Ping", expect.any(Number)]);
    expect(FakeWorker.instances[0].messages).toEqual([4_000, 4_000]);
    mayu.dispose();
    expect(FakeWorker.instances[0].messages).toContain(null);
    expect(FakeWorker.instances[0].terminated).toBe(true);
  });

  it("resets the idle ping after an outbound event", async () => {
    vi.useFakeTimers();
    vi.stubGlobal("Worker", undefined);
    const navigation = new FakeNavigation();
    vi.stubGlobal("navigation", navigation);
    const write = vi.fn(async () => undefined);
    const mayu = new Mayu();
    mayu.setWriter({ write } as any);

    await vi.advanceTimersByTimeAsync(3_000);
    const event = navigationEvent();
    navigation.dispatchEvent(event);
    await (
      event.intercept as ReturnType<typeof vi.fn>
    ).mock.calls[0][0].handler();
    await vi.runAllTicks();
    await vi.advanceTimersByTimeAsync(3_000);

    expect(write).toHaveBeenCalledTimes(1);
    expect(write).toHaveBeenCalledWith([
      "Navigate",
      "/next?tab=details",
      expect.any(Number),
    ]);

    await vi.advanceTimersByTimeAsync(1_000);

    expect(write).toHaveBeenCalledTimes(2);
    expect(write).toHaveBeenCalledWith(["Ping", expect.any(Number)]);
    mayu.dispose();
    await vi.advanceTimersByTimeAsync(5_000);
    expect(write).toHaveBeenCalledTimes(2);
  });

  it("reports visibility changes and pings when the tab is visible again", () => {
    const write = vi.fn(async () => undefined);
    const mayu = new Mayu({ autoPing: false });
    mayu.setWriter({ write } as any);

    setVisibility("hidden");
    document.dispatchEvent(new Event("visibilitychange"));
    expect(write).toHaveBeenCalledWith([
      "Visibility",
      true,
      expect.any(Number),
    ]);
    expect(write).not.toHaveBeenCalledWith(["Ping", expect.any(Number)]);

    setVisibility("visible");
    document.dispatchEvent(new Event("visibilitychange"));
    expect(write).toHaveBeenCalledWith([
      "Visibility",
      false,
      expect.any(Number),
    ]);
    expect(write).toHaveBeenCalledWith(["Ping", expect.any(Number)]);
    mayu.dispose();
  });

  it("tells a session it connects from a hidden tab", () => {
    const write = vi.fn(async () => undefined);
    const mayu = new Mayu({ autoPing: false });
    setVisibility("hidden");

    mayu.setWriter({ write } as any);

    expect(write).toHaveBeenCalledWith([
      "Visibility",
      true,
      expect.any(Number),
    ]);
    setVisibility("visible");
    mayu.dispose();
  });

  function setVisibility(value: "visible" | "hidden") {
    Object.defineProperty(document, "visibilityState", {
      value,
      configurable: true,
    });
  }
});
