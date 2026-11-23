import { afterEach, describe, expect, it, vi } from "vitest";

import TestClient from "./test-client";

describe("inspect", () => {
  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it("sends an inspect query and resolves with the answer", async () => {
    const write = vi.fn(async () => undefined);
    const mayu = new TestClient({ autoPing: false });
    mayu.setWriter({ write } as any);

    const result = mayu.inspect({ type: "tree" });
    await Promise.resolve();
    expect(write).toHaveBeenCalledWith([
      "Inspect",
      expect.any(Number),
      null,
      "1",
      { type: "tree" },
    ]);

    mayu.resolveInspect("1", { id: "v1" });
    await expect(result).resolves.toEqual({ id: "v1" });
    mayu.dispose();
  });

  it("rejects when the query can't be sent", async () => {
    vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const mayu = new TestClient({ autoPing: false });

    await expect(mayu.inspect({ type: "tree" })).rejects.toThrow(
      "Inspect not sent",
    );
    mayu.dispose();
  });

  it("rejects when no answer arrives", async () => {
    vi.useFakeTimers();
    const mayu = new TestClient({ autoPing: false });
    mayu.setWriter({ write: vi.fn(async () => undefined) } as any);

    const result = mayu.inspect({ type: "tree" });
    const assertion = expect(result).rejects.toThrow("Inspect timed out");
    await vi.advanceTimersByTimeAsync(5000);

    await assertion;
    mayu.dispose();
  });
});
