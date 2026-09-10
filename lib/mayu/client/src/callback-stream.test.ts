import { afterEach, describe, expect, it, vi } from "vitest";

describe("streaming callback transport", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.resetModules();
  });

  it("exposes structured HTTP failures", async () => {
    vi.doMock("./supportsRequestStreams", () => ({ default: true }));
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          code: "SESSION_NOT_ACCEPTING_EVENTS",
          message: "Session is transferring",
        }),
        { status: 409, headers: { "content-type": "application/json" } },
      ),
    );

    const { initCallbackStream } = await import("./stream");
    const connection = initCallbackStream("/.mayu/session/test");

    await expect(connection.failure).rejects.toEqual(
      expect.objectContaining({
        name: "StreamError",
        code: "SESSION_NOT_ACCEPTING_EVENTS",
        message: "Session is transferring",
      }),
    );
  });
});
