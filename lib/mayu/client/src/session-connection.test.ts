import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";
import { encode } from "@msgpack/msgpack";

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
      error instanceof Error ? error.message : String(error),
    ),
    shouldResetSessionMock: vi.fn(),
    resetSessionEntirelyMock: vi.fn(),
    updateConnectionStatusMock: vi.fn(),
  };
});

vi.mock("./stream.js", () => ({
  initInputStream: initInputStreamMock,
  initCallbackStream: initCallbackStreamMock,
  StreamError: class StreamError extends Error {
    constructor(
      message: string,
      public code: string | null = null,
    ) {
      super(message);
    }
  },
}));

vi.mock("./client-event-codec.js", () => ({
  ClientEventEncoderStream: class ClientEventEncoderStream extends TransformStream {},
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
import { getTransferState, setTransferState } from "./transfer";

describe("session-connection", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    setTransferState(null);
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

    const runtime = { applyBatch: vi.fn() };
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

  it("routes TransferFailed into session recovery", async () => {
    initInputStreamMock.mockResolvedValueOnce(
      new ReadableStream({
        start(controller) {
          controller.enqueue(encode([["TransferFailed"]]));
          controller.close();
        },
      }),
    );
    initCallbackStreamMock.mockReturnValue({
      writable: new WritableStream(),
      failure: null,
    });
    shouldResetSessionMock.mockReturnValue(true);
    resetSessionEntirelyMock.mockRejectedValue(
      new Error("server still draining"),
    );
    const stop = new Error("stop test loop");
    const runtime = { applyBatch: vi.fn() };
    const connection = new SessionConnection({
      runtime: runtime as any,
      mayu: { setWriter: vi.fn(), clearWriter: vi.fn() } as any,
      endpoint: "/.mayu/session/test",
      sleep: async () => {
        throw stop;
      },
    });
    await expect(connection.run()).rejects.toBe(stop);
    expect(runtime.applyBatch).not.toHaveBeenCalled();
    expect(shouldResetSessionMock).toHaveBeenCalledWith(
      expect.objectContaining({ code: "TRANSFER_FAILED" }),
    );
    expect(resetSessionEntirelyMock).toHaveBeenCalledTimes(1);
  });

  it("marks the connection disconnected after the command stream closes", async () => {
    const stop = new Error("stop test loop");
    initInputStreamMock.mockResolvedValueOnce(
      new ReadableStream({
        start(controller) {
          controller.close();
        },
      }),
    );
    initInputStreamMock.mockRejectedValueOnce(new Error("reconnect failed"));
    initCallbackStreamMock.mockReturnValue({
      writable: new WritableStream(),
      failure: null,
    });
    shouldResetSessionMock.mockReturnValue(false);

    const connection = new SessionConnection({
      runtime: { applyBatch: vi.fn() } as any,
      mayu: { setWriter: vi.fn(), clearWriter: vi.fn() } as any,
      endpoint: "/.mayu/session/test",
      sleep: async () => {
        throw stop;
      },
    });

    await expect(connection.run()).rejects.toBe(stop);

    expect(
      updateConnectionStatusMock.mock.calls.map(([status]) => status),
    ).toEqual(["disconnected", "connected", "disconnected", "disconnected"]);
  });

  it("retains transferred state when a draining server rejects reconnection", async () => {
    const state = new Blob(["encrypted state"]);
    setTransferState(state);
    initInputStreamMock.mockRejectedValue(new Error("Server is stopping"));
    shouldResetSessionMock.mockReturnValue(false);
    const stop = new Error("stop test loop");
    const connection = new SessionConnection({
      runtime: { applyBatch: vi.fn() } as any,
      mayu: { setWriter: vi.fn(), clearWriter: vi.fn() } as any,
      endpoint: "/.mayu/session/test",
      sleep: async () => {
        throw stop;
      },
    });
    await expect(connection.run()).rejects.toBe(stop);
    expect(getTransferState()).toBe(state);
    expect(resetSessionEntirelyMock).not.toHaveBeenCalled();
  });

  it("reconnects when the callback transport fails", async () => {
    const callbackError = new Error("callback stream failed");
    const stop = new Error("stop test loop");
    initInputStreamMock.mockResolvedValue(new ReadableStream({ start() {} }));
    initCallbackStreamMock.mockReturnValue({
      writable: new WritableStream(),
      failure: Promise.reject(callbackError),
    });
    shouldResetSessionMock.mockReturnValue(false);
    const sleepMock = vi.fn(async () => {
      throw stop;
    });

    const connection = new SessionConnection({
      runtime: { applyBatch: vi.fn() } as any,
      mayu: { setWriter: vi.fn(), clearWriter: vi.fn() } as any,
      endpoint: "/.mayu/session/test",
      sleep: sleepMock,
    });

    await expect(connection.run()).rejects.toBe(stop);
    expect(shouldResetSessionMock).toHaveBeenCalledWith(callbackError);
    expect(sleepMock).toHaveBeenCalledWith(1000);
  });

  it("backs off after repeated clean stream endings", async () => {
    const stop = new Error("stop test loop");
    initInputStreamMock.mockResolvedValue(
      new ReadableStream({
        start(controller) {
          controller.close();
        },
      }),
    );
    initCallbackStreamMock.mockReturnValue({
      writable: new WritableStream(),
      failure: null,
    });
    const sleepMock = vi.fn(async () => {
      throw stop;
    });

    const connection = new SessionConnection({
      runtime: { applyBatch: vi.fn() } as any,
      mayu: { setWriter: vi.fn(), clearWriter: vi.fn() } as any,
      endpoint: "/.mayu/session/test",
      sleep: sleepMock,
    });

    await expect(connection.run()).rejects.toBe(stop);
    expect(sleepMock).toHaveBeenCalledWith(1000);
    expect(initInputStreamMock).toHaveBeenCalledTimes(2);
  });
});
