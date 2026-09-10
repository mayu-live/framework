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
