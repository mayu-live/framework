import { afterEach, describe, expect, it, vi } from "vitest";

import type { ClientEvent } from "../protocol/events";
import Outbox from "./outbox";

describe("Outbox", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("puts the header in front of an event's arguments", async () => {
    const outbox = new Outbox();
    const write = vi.fn(async (_event: ClientEvent) => undefined);
    outbox.attach({ write } as any);

    expect(await outbox.send(["Navigate", "1", "/next"])).toBe(true);

    expect(write).toHaveBeenCalledWith([
      "Navigate",
      expect.any(Number),
      null,
      null,
      "1",
      "/next",
    ]);
  });

  it("acknowledges the last applied batch in every event", async () => {
    const outbox = new Outbox();
    const write = vi.fn(async (_event: ClientEvent) => undefined);
    outbox.attach({ write } as any);

    outbox.acknowledge(7);
    await outbox.send(["Ping"]);
    await outbox.send(["Ping"]);
    outbox.acknowledge(null);
    await outbox.send(["Ping"]);

    expect(write.mock.calls.map(([event]) => event[2])).toEqual([7, 7, null]);
  });

  it("drops an event when nothing is attached", async () => {
    vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const outbox = new Outbox();

    expect(await outbox.send(["Ping"])).toBe(false);
    expect(outbox.connected).toBe(false);
  });

  it("detaches and tells its listeners when a write fails", async () => {
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    const outbox = new Outbox();
    const disconnected = vi.fn();
    outbox.onDisconnect(disconnected);
    outbox.attach({
      write: vi.fn(async () => {
        throw new Error("closed");
      }),
    } as any);

    expect(await outbox.send(["Ping"])).toBe(false);
    expect(disconnected).toHaveBeenCalledOnce();
    expect(outbox.connected).toBe(false);
  });
});
