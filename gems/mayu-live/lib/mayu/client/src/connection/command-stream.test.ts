import { afterEach, describe, expect, it, vi } from "vitest";

import { connect } from "./command-stream";
import { StreamError } from "./stream-error";

describe("command stream", () => {
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

  it("reports a failed response without a structured payload", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response("Server is stopping", { status: 503 }),
    );

    let thrown: unknown;
    try {
      await connect("/.mayu/session/abc");
    } catch (error) {
      thrown = error;
    }

    expect(thrown).toBeInstanceOf(StreamError);
    expect((thrown as StreamError).message).toBe("Unknown stream error");
    expect((thrown as StreamError).code).toBeNull();
  });
});
