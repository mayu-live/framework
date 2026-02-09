import { afterEach, describe, expect, it, vi } from "vitest";

import { connect, StreamError } from "./stream";

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
        }
      )
    );

    await expect(connect("/.mayu/session/abc")).rejects.toEqual(
      expect.objectContaining({
        name: "StreamError",
        message: "Session not found",
        code: "SESSION_NOT_FOUND",
      })
    );
  });

  it("supports legacy error payload shape", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ error: "expired" }), {
        status: 403,
        headers: { "content-type": "application/json" },
      })
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
});
