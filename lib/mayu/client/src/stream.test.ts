import { afterEach, describe, expect, it, vi } from "vitest";

import { connect, initCallbackStream, StreamError } from "./stream";
import { STREAM_MIME_TYPE } from "./constants";

describe("stream", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("parses structured error payload with code/message", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          code: "SESSION_NOT_FOUND",
          message: "Session not found",
        }),
        {
          status: 403,
          headers: { "content-type": "application/json" },
        },
      ),
    );

    await expect(connect("/.mayu/session/abc")).rejects.toEqual(
      expect.objectContaining({
        name: "StreamError",
        message: "Session not found",
        code: "SESSION_NOT_FOUND",
      }),
    );
  });

  it("supports legacy error payload shape", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ error: "expired" }), {
        status: 403,
        headers: { "content-type": "application/json" },
      }),
    );

    let thrown: unknown;
    try {
      await connect("/.mayu/session/abc");
    } catch (error) {
      thrown = error;
    }

    expect(thrown).toBeInstanceOf(StreamError);
    expect((thrown as StreamError).message).toBe("expired");
    expect((thrown as StreamError).code).toBeNull();
  });

  it("rejects failed per-message callback requests", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          code: "INVALID_EVENT_MESSAGE",
          message: "Invalid event message",
        }),
        { status: 400, headers: { "content-type": "application/json" } },
      ),
    );

    const connection = initCallbackStream("/.mayu/session/abc");
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
  });
});
