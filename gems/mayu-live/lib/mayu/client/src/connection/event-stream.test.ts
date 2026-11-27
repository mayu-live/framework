import { afterEach, describe, expect, it, vi } from "vitest";

import { STREAM_MIME_TYPE } from "../protocol/constants";

describe("event stream", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.resetModules();
    vi.doUnmock("./supports-request-streams");
  });

  it("exposes structured HTTP failures", async () => {
    vi.doMock("./supports-request-streams", () => ({ default: true }));
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          code: "SESSION_NOT_ACCEPTING_EVENTS",
          message: "Session is transferring",
        }),
        { status: 409, headers: { "content-type": "application/json" } },
      ),
    );

    const { openEventStream } = await import("./event-stream");
    const connection = openEventStream("/.mayu/session/test");

    await expect(connection.failure).rejects.toEqual(
      expect.objectContaining({
        name: "StreamError",
        code: "SESSION_NOT_ACCEPTING_EVENTS",
        message: "Session is transferring",
      }),
    );
  });

  it("rejects failed per-event requests where request streams are unsupported", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          code: "INVALID_EVENT_MESSAGE",
          message: "Invalid event message",
        }),
        { status: 400, headers: { "content-type": "application/json" } },
      ),
    );

    const { openEventStream } = await import("./event-stream");
    const connection = openEventStream("/.mayu/session/abc");
    const writer = connection.writable.getWriter();
    const frame = new Uint8Array([0xc0]);

    await expect(writer.write(frame)).rejects.toEqual(
      expect.objectContaining({
        name: "StreamError",
        code: "INVALID_EVENT_MESSAGE",
      }),
    );

    const request = fetchMock.mock.calls[0]?.[1];
    expect(request?.body).toBe(frame);
    expect((request?.headers as Headers).get("content-type")).toBe(
      STREAM_MIME_TYPE,
    );
    expect((request?.headers as Headers).get("mayu-protocol")).toBe("2");
  });
});
