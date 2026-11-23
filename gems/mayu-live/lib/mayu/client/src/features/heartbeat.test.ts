import { afterEach, describe, expect, it, vi } from "vitest";

import TestClient, { FakeNavigation, navigationEvent } from "./test-client";

describe("pings", () => {
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
    const mayu = new TestClient();
    mayu.setWriter({ write } as any);

    expect(FakeWorker.instances).toHaveLength(1);
    expect(FakeWorker.instances[0].messages).toEqual([4_000]);
    FakeWorker.instances[0].onmessage!(new MessageEvent("message"));
    await Promise.resolve();

    expect(write).toHaveBeenCalledWith(["Ping", expect.any(Number), null]);
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
    const mayu = new TestClient();
    mayu.setWriter({ write } as any);

    await vi.advanceTimersByTimeAsync(3_000);
    const event = navigationEvent();
    navigation.dispatchEvent(event);
    const handled = (
      event.intercept as ReturnType<typeof vi.fn>
    ).mock.calls[0][0].handler();
    await Promise.resolve();
    mayu.completeNavigation("1");
    await handled;
    await vi.runAllTicks();
    await vi.advanceTimersByTimeAsync(3_000);

    expect(write).toHaveBeenCalledTimes(1);
    expect(write).toHaveBeenCalledWith([
      "Navigate",
      expect.any(Number),
      null,
      "1",
      "/next?tab=details",
    ]);

    await vi.advanceTimersByTimeAsync(1_000);

    expect(write).toHaveBeenCalledTimes(2);
    expect(write).toHaveBeenCalledWith(["Ping", expect.any(Number), null]);
    mayu.dispose();
    await vi.advanceTimersByTimeAsync(5_000);
    expect(write).toHaveBeenCalledTimes(2);
  });

  it("reports visibility changes and pings when the tab is visible again", () => {
    const write = vi.fn(async () => undefined);
    const mayu = new TestClient({ autoPing: false });
    mayu.setWriter({ write } as any);

    setVisibility("hidden");
    document.dispatchEvent(new Event("visibilitychange"));
    expect(write).toHaveBeenCalledWith([
      "Visibility",
      expect.any(Number),
      null,
      true,
    ]);
    expect(write).not.toHaveBeenCalledWith(["Ping", expect.any(Number), null]);

    setVisibility("visible");
    document.dispatchEvent(new Event("visibilitychange"));
    expect(write).toHaveBeenCalledWith([
      "Visibility",
      expect.any(Number),
      null,
      false,
    ]);
    expect(write).toHaveBeenCalledWith(["Ping", expect.any(Number), null]);
    mayu.dispose();
  });

  it("tells a session it connects from a hidden tab", () => {
    const write = vi.fn(async () => undefined);
    const mayu = new TestClient({ autoPing: false });
    setVisibility("hidden");

    mayu.setWriter({ write } as any);

    expect(write).toHaveBeenCalledWith([
      "Visibility",
      expect.any(Number),
      null,
      true,
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
