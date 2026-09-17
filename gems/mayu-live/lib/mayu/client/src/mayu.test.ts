import { afterEach, describe, expect, it, vi } from "vitest";

import Mayu from "./mayu";
import type { ClientEvent } from "./protocol";

describe("Mayu callbacks", () => {
  afterEach(() => {
    document.body.innerHTML = "";
    vi.useRealTimers();
    vi.restoreAllMocks();
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
    constructor(public url: string) {
      FakeWorker.instances.push(this);
    }
    terminate() {
      this.terminated = true;
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

  it("pings from a worker ticker, which hidden tabs do not throttle", () => {
    stubWorker();
    const write = vi.fn(async () => undefined);
    const mayu = new Mayu();
    mayu.setWriter({ write } as any);

    expect(FakeWorker.instances).toHaveLength(1);
    FakeWorker.instances[0].onmessage!(new MessageEvent("message"));

    expect(write).toHaveBeenCalledWith(["Ping", expect.any(Number)]);
    mayu.dispose();
    expect(FakeWorker.instances[0].terminated).toBe(true);
  });

  it("falls back to a page timer without workers", () => {
    vi.useFakeTimers();
    vi.stubGlobal("Worker", undefined);
    const write = vi.fn(async () => undefined);
    const mayu = new Mayu();
    mayu.setWriter({ write } as any);

    vi.advanceTimersByTime(2_500);

    expect(write).toHaveBeenCalledTimes(2);
    expect(write).toHaveBeenCalledWith(["Ping", expect.any(Number)]);
    mayu.dispose();
    vi.advanceTimersByTime(5_000);
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
