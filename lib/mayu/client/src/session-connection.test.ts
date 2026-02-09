import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";

const {
  initInputStreamMock,
  initCallbackStreamMock,
  getErrorMessageMock,
  shouldResetSessionMock,
  resetSessionEntirelyMock,
  updateConnectionStatusMock,
} = vi.hoisted(() => {
  return {
    initInputStreamMock: vi.fn(),
    initCallbackStreamMock: vi.fn(),
    getErrorMessageMock: vi.fn((error: unknown) =>
      error instanceof Error ? error.message : String(error)
    ),
    shouldResetSessionMock: vi.fn(),
    resetSessionEntirelyMock: vi.fn(),
    updateConnectionStatusMock: vi.fn(),
  };
});

vi.mock("./stream.js", () => ({
  initInputStream: initInputStreamMock,
  initCallbackStream: initCallbackStreamMock,
  JSONEncoderStream: class JSONEncoderStream extends TransformStream {},
  StreamError: class StreamError extends Error {},
}));

vi.mock("./session-recovery.js", () => ({
  getErrorMessage: getErrorMessageMock,
  shouldResetSession: shouldResetSessionMock,
  resetSessionEntirely: resetSessionEntirelyMock,
}));

vi.mock("./ping", () => ({
  updateConnectionStatus: updateConnectionStatusMock,
}));

import SessionConnection from "./session-connection";

describe("session-connection", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    vi.spyOn(console, "warn").mockImplementation(() => undefined);
    vi.spyOn(console, "info").mockImplementation(() => undefined);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("falls back to retry sleep when session reset fails", async () => {
    const inputError = new Error("stream down");
    const resetError = new Error("reset failed");
    const stopError = new Error("stop test loop");

    initInputStreamMock.mockRejectedValue(inputError);
    shouldResetSessionMock.mockReturnValue(true);
    resetSessionEntirelyMock.mockRejectedValue(resetError);

    const sleepMock = vi.fn(async () => {
      throw stopError;
    });

    const runtime = { apply: vi.fn() };
    const mayu = {
      setWriter: vi.fn(),
      clearWriter: vi.fn(),
    };

    const connection = new SessionConnection({
      runtime: runtime as any,
      mayu: mayu as any,
      endpoint: "/.mayu/session/test",
      sleep: sleepMock,
    });

    await expect(connection.run()).rejects.toBe(stopError);

    expect(shouldResetSessionMock).toHaveBeenCalledWith(inputError);
    expect(resetSessionEntirelyMock).toHaveBeenCalledTimes(1);
    expect(sleepMock).toHaveBeenCalledWith(1000);
    expect(mayu.clearWriter).toHaveBeenCalled();
  });
});
