import { afterEach, describe, expect, it, vi } from "vitest";

import {
  getErrorCode,
  getErrorMessage,
  resetSessionEntirely,
  shouldResetSession,
} from "./session-recovery";

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
    expect(shouldResetSession(new Error("expired"))).toBe(true);
    expect(shouldResetSession(new Error("cipher error"))).toBe(true);
    expect(shouldResetSession(new Error("Session not found"))).toBe(true);
    expect(shouldResetSession(new Error("Token cookie not set"))).toBe(true);
    expect(shouldResetSession(new Error("SESSION_NOT_FOUND"))).toBe(true);
    expect(shouldResetSession(new Error("TOKEN_COOKIE_NOT_SET"))).toBe(true);
    expect(shouldResetSession(new Error("SESSION_CIPHER_ERROR"))).toBe(true);
    expect(shouldResetSession(new Error("SESSION_EXPIRED"))).toBe(true);
    expect(
      shouldResetSession(
        Object.assign(new Error("expired"), { code: "SESSION_EXPIRED" })
      )
    ).toBe(true);
    expect(
      shouldResetSession(
        Object.assign(new Error("whatever"), {
          code: "TOKEN_COOKIE_NOT_SET",
        })
      )
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
      })
    );

    await expect(resetSessionEntirely()).rejects.toThrow(
      "Missing x-mayu-session-id header during session reset"
    );
  });
});
