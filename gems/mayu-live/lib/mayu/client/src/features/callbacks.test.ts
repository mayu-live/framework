import { afterEach, describe, expect, it, vi } from "vitest";

import type { ClientEvent } from "../protocol/events";
import { settled } from "./settled";
import TestClient from "./test-client";

describe("callbacks", () => {
  afterEach(() => {
    document.body.innerHTML = "";
    vi.useRealTimers();
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it("drops events explicitly when no callback transport is active", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const mayu = new TestClient({ autoPing: false });
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
    const mayu = new TestClient({ autoPing: false });
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
    const mayu = new TestClient({ autoPing: false });
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

  it("lets command invoker buttons keep their default action", () => {
    const mayu = new TestClient({ autoPing: false });
    mayu.setWriter({ write: vi.fn(async () => undefined) } as any);
    const button = document.createElement("button");
    button.setAttribute("commandfor", "dialog");
    button.setAttribute("command", "show-modal");
    button.addEventListener("click", (event) =>
      mayu.callback(event, "listener"),
    );
    document.body.append(button);

    const event = new MouseEvent("click", { cancelable: true });
    button.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(false);
    mayu.dispose();
  });

  describe("submitting a form", () => {
    function submit(method: string, submitterMethod?: string) {
      const mayu = new TestClient({ autoPing: false });
      mayu.setWriter({ write: vi.fn(async () => undefined) } as any);
      const form = document.createElement("form");
      form.setAttribute("method", method);
      const submitter = document.createElement("button");
      if (submitterMethod)
        submitter.setAttribute("formmethod", submitterMethod);
      form.append(submitter);
      form.addEventListener("submit", (event) =>
        mayu.callback(event, "listener"),
      );
      document.body.append(form);

      const event = new SubmitEvent("submit", { cancelable: true, submitter });
      form.dispatchEvent(event);
      mayu.dispose();
      return event;
    }

    it("lets a dialog form close its dialog", () => {
      expect(submit("dialog").defaultPrevented).toBe(false);
    });

    it("lets a submitter with formmethod=dialog close its dialog", () => {
      expect(submit("post", "dialog").defaultPrevented).toBe(false);
    });

    it("prevents other submissions", () => {
      expect(submit("post").defaultPrevented).toBe(true);
      expect(submit("dialog", "post").defaultPrevented).toBe(true);
    });
  });

  it("does not throttle discrete events", async () => {
    const mayu = new TestClient({ autoPing: false });
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

  it("attaches accumulated command-apply telemetry to the next event", async () => {
    const mayu = new TestClient({ autoPing: false });
    const write = vi.fn(async (_message: ClientEvent) => undefined);
    mayu.setWriter({ write } as any);

    mayu.recordCommandApply(2, 1.25);
    mayu.recordCommandApply(3, 2.5);
    mayu.ping();
    await Promise.resolve();

    expect(write).toHaveBeenCalledWith([
      "Ping",
      expect.any(Number),
      { batches: 2, commands: 5, duration_ms: 3.75 },
    ]);

    mayu.ping();
    await Promise.resolve();
    expect(write).toHaveBeenLastCalledWith(["Ping", expect.any(Number), null]);
    mayu.dispose();
  });

  it("sends Backspace keydown callbacks", async () => {
    const mayu = new TestClient({ autoPing: false });
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
    const mayu = new TestClient({ autoPing: false });
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
    expect((message?.[4] as any).target.value).toBe("abc");
    mayu.dispose();
  });

  it("opens a new throttle window after sending a trailing event", async () => {
    vi.useFakeTimers();
    const mayu = new TestClient({ autoPing: false });
    const write = vi.fn(async (_message: ClientEvent) => undefined);
    mayu.setWriter({ write } as any);
    const pad = document.createElement("div");
    pad.addEventListener("pointermove", (event) =>
      mayu.callback(event, "listener"),
    );
    document.body.append(pad);

    // Pointer events at 60 Hz for one second.
    for (let i = 0; i < 60; i++) {
      pad.dispatchEvent(new MouseEvent("pointermove", { clientX: i }));
      await vi.advanceTimersByTimeAsync(1_000 / 60);
    }
    await vi.runAllTimersAsync();

    expect(write.mock.calls.length).toBeGreaterThanOrEqual(29);
    expect(write.mock.calls.length).toBeLessThanOrEqual(32);
    const last = write.mock.calls.at(-1)?.[0];
    expect((last?.[4] as any).clientX).toBe(59);
    mayu.dispose();
  });

  it("throttles scroll events", async () => {
    vi.useFakeTimers();
    const mayu = new TestClient({ autoPing: false });
    const write = vi.fn(async (_message: ClientEvent) => undefined);
    mayu.setWriter({ write } as any);
    const list = document.createElement("div");
    list.addEventListener("scroll", (event) =>
      mayu.callback(event, "listener"),
    );
    document.body.append(list);

    for (let i = 0; i < 10; i++) list.dispatchEvent(new Event("scroll"));
    await vi.runAllTimersAsync();

    expect(write).toHaveBeenCalledTimes(2);
    mayu.dispose();
  });

  it("sends pending continuous events before a discrete event", async () => {
    vi.useFakeTimers();
    const mayu = new TestClient({ autoPing: false });
    const write = vi.fn(async (_message: ClientEvent) => undefined);
    mayu.setWriter({ write } as any);
    const form = document.createElement("form");
    const input = document.createElement("input");
    form.append(input);
    input.addEventListener("input", (event) =>
      mayu.callback(event, "input-listener"),
    );
    form.addEventListener("submit", (event) =>
      mayu.callback(event, "submit-listener"),
    );
    document.body.append(form);

    input.value = "a";
    input.dispatchEvent(new InputEvent("input"));
    input.value = "ab";
    input.dispatchEvent(new InputEvent("input"));
    form.dispatchEvent(new SubmitEvent("submit", { cancelable: true }));
    await vi.runAllTimersAsync();

    const sent = write.mock.calls.map(([message]) => [
      message[3],
      (message[4] as any).target?.value,
    ]);
    expect(sent).toEqual([
      ["input-listener", "a"],
      ["input-listener", "ab"],
      ["submit-listener", undefined],
    ]);
    mayu.dispose();
  });
});

describe("callback settlement", () => {
  afterEach(() => {
    document.body.innerHTML = "";
    vi.restoreAllMocks();
  });

  // A connected Mayu whose callbacks are sent by `element`'s listeners.
  function setup() {
    const mayu = new TestClient({ autoPing: false });
    const write = vi.fn(async (_message: ClientEvent) => undefined);
    mayu.setWriter({ write } as any);
    const settleIds = () =>
      write.mock.calls
        .map(([message]) => message)
        .filter((message) => message[0] === "Callback")
        .map((message) => message[5] as string | undefined);
    return { mayu, write, settleIds };
  }

  function listen(
    mayu: TestClient,
    element: Element,
    type: string,
    id: string,
  ) {
    element.addEventListener(type, (event) => mayu.callback(event, id));
  }

  it("sends a settle id with discrete events but not continuous ones", async () => {
    vi.useFakeTimers();
    const { mayu, settleIds } = setup();
    const input = document.createElement("input");
    listen(mayu, input, "input", "input-listener");
    listen(mayu, input, "change", "change-listener");
    document.body.append(input);

    input.dispatchEvent(new Event("input"));
    input.dispatchEvent(new Event("change"));
    await vi.runAllTimersAsync();

    expect(settleIds()).toEqual([undefined, "1"]);
    mayu.dispose();
    vi.useRealTimers();
  });

  it("resolves once the server completes the callback", async () => {
    const { mayu, settleIds } = setup();
    const button = document.createElement("button");
    listen(mayu, button, "click", "listener");
    document.body.append(button);

    const event = new MouseEvent("click", { cancelable: true });
    button.dispatchEvent(event);
    await Promise.resolve();
    let done = false;
    const promise = settled(event).then(() => (done = true));

    await Promise.resolve();
    expect(done).toBe(false);
    mayu.completeCallback(settleIds()[0]!);
    await promise;
    expect(done).toBe(true);
    mayu.dispose();
  });

  it("rejects when the server reports failure", async () => {
    const { mayu, settleIds } = setup();
    const button = document.createElement("button");
    listen(mayu, button, "click", "listener");
    document.body.append(button);

    const event = new MouseEvent("click", { cancelable: true });
    button.dispatchEvent(event);
    await Promise.resolve();
    mayu.failCallback(settleIds()[0]!);

    await expect(settled(event)).rejects.toThrow("Callback failed");
    mayu.dispose();
  });

  it("waits for every Mayu handler the event reached", async () => {
    const { mayu, settleIds } = setup();
    const parent = document.createElement("div");
    const child = document.createElement("button");
    parent.append(child);
    listen(mayu, child, "click", "child");
    listen(mayu, parent, "click", "parent");
    document.body.append(parent);

    const event = new MouseEvent("click", { bubbles: true, cancelable: true });
    child.dispatchEvent(event);
    await Promise.resolve();
    let done = false;
    const promise = settled(event).then(() => (done = true));

    mayu.completeCallback(settleIds()[0]!);
    await Promise.resolve();
    await Promise.resolve();
    expect(done).toBe(false);
    mayu.completeCallback(settleIds()[1]!);
    await promise;
    mayu.dispose();
  });

  it("resolves right away for events no Mayu handler received", async () => {
    await expect(settled(new Event("click"))).resolves.toBeUndefined();
  });

  it("rejects pending callbacks when the transport goes away", async () => {
    const { mayu } = setup();
    const button = document.createElement("button");
    listen(mayu, button, "click", "listener");
    document.body.append(button);

    const event = new MouseEvent("click", { cancelable: true });
    button.dispatchEvent(event);
    mayu.clearWriter();

    await expect(settled(event)).rejects.toThrow(
      "Callback transport unavailable",
    );
    mayu.dispose();
  });

  it("rejects pending callbacks when disposed", async () => {
    const { mayu } = setup();
    const button = document.createElement("button");
    listen(mayu, button, "click", "listener");
    document.body.append(button);

    const event = new MouseEvent("click", { cancelable: true });
    button.dispatchEvent(event);
    mayu.dispose();

    await expect(settled(event)).rejects.toThrow("Mayu was disposed");
  });

  it("rejects when the callback can't be sent", async () => {
    vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const mayu = new TestClient({ autoPing: false });
    const button = document.createElement("button");
    listen(mayu, button, "click", "listener");
    document.body.append(button);

    const event = new MouseEvent("click", { cancelable: true });
    button.dispatchEvent(event);

    await expect(settled(event)).rejects.toThrow("Callback not sent");
    mayu.dispose();
  });
});
