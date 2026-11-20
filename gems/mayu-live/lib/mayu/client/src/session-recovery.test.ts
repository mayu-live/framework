import { afterEach, describe, expect, it, vi } from "vitest";

import {
  getErrorCode,
  getErrorMessage,
  resetSessionEntirely,
  shouldResetSession,
} from "./session-recovery";
import { getTransferState, setTransferState } from "./transfer";

describe("session-recovery", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    setTransferState(null);
  });

  it("extracts error messages from string and Error values", () => {
    expect(getErrorMessage("boom")).toBe("boom");
    expect(getErrorMessage(new Error("oops"))).toBe("oops");
    expect(getErrorMessage({})).toBeNull();
  });

  it("extracts error codes from error-like values", () => {
    const codedError = Object.assign(new Error("oops"), {
      code: "SESSION_EXPIRED",
    });

    expect(getErrorCode(codedError)).toBe("SESSION_EXPIRED");
    expect(getErrorCode(new Error("oops"))).toBeNull();
    expect(getErrorCode({ code: 12 })).toBeNull();
  });

  it("matches reset-worthy stream errors", () => {
    expect(shouldResetSession({ code: "TRANSFER_FAILED" })).toBe(true);
    expect(shouldResetSession(new Error("expired"))).toBe(true);
    expect(shouldResetSession(new Error("cipher error"))).toBe(true);
    expect(shouldResetSession(new Error("Session not found"))).toBe(true);
    expect(shouldResetSession(new Error("Token cookie not set"))).toBe(true);
    expect(shouldResetSession(new Error("SESSION_NOT_FOUND"))).toBe(true);
    expect(shouldResetSession(new Error("TOKEN_COOKIE_NOT_SET"))).toBe(true);
    expect(shouldResetSession(new Error("SESSION_CIPHER_ERROR"))).toBe(true);
    expect(shouldResetSession(new Error("SESSION_EXPIRED"))).toBe(true);
    expect(shouldResetSession({ code: "SESSION_RESTORE_FAILED" })).toBe(true);
    expect(
      shouldResetSession(
        Object.assign(new Error("expired"), { code: "SESSION_EXPIRED" }),
      ),
    ).toBe(true);
    expect(
      shouldResetSession(
        Object.assign(new Error("whatever"), {
          code: "TOKEN_COOKIE_NOT_SET",
        }),
      ),
    ).toBe(true);
  });

  it("does not match unrelated errors", () => {
    expect(shouldResetSession(new Error("random network error"))).toBe(false);
    expect(shouldResetSession("Unknown error")).toBe(false);
  });

  it("raises when reset response is missing x-mayu-session-id", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response("<!DOCTYPE html>\n<html></html>", {
        status: 200,
        headers: {
          "content-type": "text/html",
        },
      }),
    );

    await expect(resetSessionEntirely()).rejects.toThrow(
      "Missing x-mayu-session-id header during session reset",
    );
  });

  it.each([null, "/login?expired=1"])(
    "preserves authorization rejection with destination %s without changing the page",
    async (location) => {
      const html = document.documentElement.outerHTML;
      const fetch = vi.spyOn(globalThis, "fetch").mockResolvedValue(
        new Response(
          JSON.stringify({ code: "APPLICATION_SESSION_REJECTED", location }),
          {
            status: 403,
            headers: { "content-type": "application/json" },
          },
        ),
      );
      await expect(resetSessionEntirely()).rejects.toEqual(
        expect.objectContaining({
          name: "StreamError",
          code: "APPLICATION_SESSION_REJECTED",
          location,
        }),
      );
      const options = fetch.mock.calls[0][1]!;
      const headers = new Headers(options.headers);
      expect(headers.get("accept")).toBe("text/html");
      expect(headers.get("x-mayu-session-recovery")).toBe("1");
      expect(document.documentElement.outerHTML).toBe(html);
    },
  );

  it("keeps ordinary HTTP failures distinct from authorization rejection", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response("Unavailable", { status: 503 }),
    );
    await expect(resetSessionEntirely()).rejects.toEqual(
      expect.objectContaining({
        name: "StreamError",
        message: "Session reset failed",
        code: null,
        location: null,
      }),
    );
  });

  it("still restores an authorized replacement session", async () => {
    setTransferState(new Blob(["old transfer"]));
    vi.spyOn(console, "warn").mockImplementation(() => {});
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(document.documentElement.outerHTML, {
        headers: {
          "content-type": "text/html",
          "x-mayu-session-id": "replacement",
        },
      }),
    );
    await expect(resetSessionEntirely()).resolves.toBe(
      "/.mayu/session/replacement",
    );
    expect(getTransferState()).toBeNull();
  });
});
