import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import Outbox from "../connection/outbox";
import type { ClientEvent } from "../protocol/events";
import Resync from "./resync";

function setup() {
  const outbox = new Outbox();
  const write = vi.fn(async (_event: ClientEvent) => undefined);
  outbox.attach({ write } as any);
  const resync = new Resync(outbox);
  const requests = () =>
    write.mock.calls
      .map(([event]) => event)
      .filter((event) => event[0] === "Resync")
      .map((event) => event[4]);
  return { outbox, resync, write, requests };
}

describe("Resync", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.spyOn(console, "warn").mockImplementation(() => undefined);
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it("asks the server for the page, with the reason", async () => {
    const { resync, requests } = setup();

    resync.request("SetAttribute: Node not found: v9");
    await vi.runAllTicks();

    expect(requests()).toEqual(["SetAttribute: Node not found: v9"]);
  });

  it("asks once while the answer is on its way", async () => {
    const { resync, requests } = setup();

    resync.request("first");
    resync.request("second");
    resync.request("third");
    await vi.runAllTicks();

    expect(requests()).toEqual(["first"]);
  });

  it("leaves the page alone when it still differs right after a resync", async () => {
    const { resync, requests } = setup();

    resync.request("first");
    resync.completed();
    resync.request("still wrong");
    resync.request("still wrong");
    await vi.runAllTicks();

    expect(requests()).toEqual(["first"]);
    expect(console.warn).toHaveBeenCalledWith(
      expect.stringContaining("left as it is"),
      "still wrong",
    );
    expect(
      vi
        .mocked(console.warn)
        .mock.calls.filter(([message]) => String(message).includes("left")),
    ).toHaveLength(1);
  });

  it("keeps leaving such a page alone", async () => {
    const { resync, requests } = setup();

    resync.request("first");
    resync.completed();
    resync.request("still wrong");
    await vi.advanceTimersByTimeAsync(60_000);
    resync.request("still wrong, later");
    await vi.runAllTicks();

    expect(requests()).toEqual(["first"]);
  });

  it("asks again for a difference that shows up later", async () => {
    const { resync, requests } = setup();

    resync.request("first");
    resync.completed();
    await vi.advanceTimersByTimeAsync(5_000);
    resync.request("later");
    await vi.runAllTicks();

    expect(requests()).toEqual(["first", "later"]);
  });

  it("asks again after the connection that carried the request is lost", async () => {
    const { outbox, resync, write, requests } = setup();

    resync.request("first");
    outbox.detach();
    outbox.attach({ write } as any);
    resync.request("after reconnecting");
    await vi.runAllTicks();

    expect(requests()).toEqual(["first", "after reconnecting"]);
  });

  it("asks again when the request could not be sent", async () => {
    const outbox = new Outbox();
    const resync = new Resync(outbox);

    resync.request("no connection");
    await vi.runAllTicks();

    const write = vi.fn(async (_event: ClientEvent) => undefined);
    outbox.attach({ write } as any);
    resync.request("connected now");
    await vi.runAllTicks();

    expect(write).toHaveBeenCalledOnce();
    expect(write.mock.calls[0][0][4]).toBe("connected now");
  });
});
