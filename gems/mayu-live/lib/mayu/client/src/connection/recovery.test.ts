import { afterEach, describe, expect, it, vi } from "vitest";

import {
  getErrorCode,
  getErrorMessage,
  resetSessionEntirely,
  shouldResetSession,
} from "./recovery";

describe("session-recovery", () => {
  afterEach(() => {
    vi.restoreAllMocks();
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
    for (const code of [
      "TRANSFER_FAILED",
      "SESSION_EXPIRED",
      "SESSION_CIPHER_ERROR",
      "SESSION_RESTORE_FAILED",
      "SESSION_NOT_FOUND",
      "TOKEN_COOKIE_NOT_SET",
    ]) {
      expect(shouldResetSession({ code })).toBe(true);
    }
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
    expect(shouldResetSession({ code: "SERVER_STOPPING" })).toBe(false);
  });

  it("matches on the code, not on the message", () => {
    expect(shouldResetSession(new Error("SESSION_NOT_FOUND"))).toBe(false);
    expect(shouldResetSession(new Error("Session not found"))).toBe(false);
  });

  it("replaces the page, and the old session's error with it", async () => {
    document.body.innerHTML = "<p>old</p><mayu-exception></mayu-exception>";
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        "<!DOCTYPE html>\n<html><head></head><body><p>new</p></body></html>",
        { status: 200, headers: { "x-mayu-session-id": "next" } },
      ),
    );

    await expect(resetSessionEntirely()).resolves.toBe("/.mayu/session/next");

    expect(document.body.innerHTML).toBe("<p>new</p>");
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
});
