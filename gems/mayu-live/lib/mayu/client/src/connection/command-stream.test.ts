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

  it("names the last applied batch when it has one", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockImplementation(
      async () =>
        new Response("", {
          status: 200,
          headers: {
            "content-type": "application/vnd.mayu.event-stream",
            "mayu-protocol": "2",
          },
        }),
    );
    vi.spyOn(console, "info").mockImplementation(() => undefined);

    await connect("/.mayu/session/abc");
    await connect("/.mayu/session/abc", null, undefined, 0);
    await connect("/.mayu/session/abc", null, undefined, 12);

    const sent = fetchMock.mock.calls.map(([, init]) =>
      (init!.headers as Headers).get("mayu-last-batch"),
    );
    expect(sent).toEqual([null, "0", "12"]);
  });

  it("names its version, and refuses a server that names another or none", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockImplementation(
      async () =>
        new Response("", {
          status: 200,
          headers: { "content-type": "application/vnd.mayu.event-stream" },
        }),
    );
    vi.spyOn(console, "info").mockImplementation(() => undefined);

    await expect(connect("/.mayu/session/abc")).rejects.toEqual(
      expect.objectContaining({ code: "PROTOCOL_MISMATCH" }),
    );

    const [, init] = fetchMock.mock.calls[0];
    expect((init!.headers as Headers).get("mayu-protocol")).toBe("2");
  });

  it("resumes a transfer with a POST that names no batch", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response("", {
        status: 200,
        headers: {
          "content-type": "application/vnd.mayu.event-stream",
          "mayu-protocol": "2",
        },
      }),
    );
    vi.spyOn(console, "info").mockImplementation(() => undefined);
    const state = new Blob(["state"]);

    await connect("/.mayu/session/abc", state, undefined, 12);

    const [, init] = fetchMock.mock.calls[0];
    expect(init!.method).toBe("POST");
    expect(init!.body).toBe(state);
    expect((init!.headers as Headers).has("mayu-last-batch")).toBe(false);
  });
});
