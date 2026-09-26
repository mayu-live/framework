import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";
import { encode } from "@msgpack/msgpack";

const {
  initInputStreamMock,
  initCallbackStreamMock,
  getErrorMessageMock,
  shouldResetSessionMock,
  resetSessionEntirelyMock,
  updateConnectionStatusMock,
  updateReconnectStatusMock,
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
    updateReconnectStatusMock: vi.fn(),
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
  updateReconnectStatus: updateReconnectStatusMock,
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
    ).toEqual(["disconnected", "disconnected"]);
  });

  it("reports reconnect attempts and when the next one starts", async () => {
    const stop = new Error("stop test loop");
    vi.spyOn(Date, "now").mockReturnValue(10_000);
    initInputStreamMock.mockRejectedValue(new Error("stream down"));
    shouldResetSessionMock.mockReturnValue(false);
    const sleepMock = vi
      .fn()
      .mockResolvedValueOnce(undefined)
      .mockRejectedValueOnce(stop);

    const connection = new SessionConnection({
      runtime: { applyBatch: vi.fn() } as any,
      mayu: { setWriter: vi.fn(), clearWriter: vi.fn() } as any,
      endpoint: "/.mayu/session/test",
      sleep: sleepMock,
    });

    await expect(connection.run()).rejects.toBe(stop);

    expect(
      updateReconnectStatusMock.mock.calls.map(([status]) => status),
    ).toEqual([
      { attempt: 1, retryAt: null },
      { attempt: 1, retryAt: 11_000 },
      { attempt: 2, retryAt: null },
      { attempt: 2, retryAt: 12_000 },
    ]);
  });

  it("keeps the transfer dialog open until the resumed stream sends a batch", async () => {
    const state = new Blob(["encrypted state"]);
    const stop = new Error("stop test loop");
    let resolveInput!: (stream: ReadableStream<Uint8Array>) => void;
    setTransferState(state);
    initInputStreamMock.mockReturnValueOnce(
      new Promise<ReadableStream<Uint8Array>>((resolve) => {
        resolveInput = resolve;
      }),
    );
    initCallbackStreamMock.mockReturnValue({
      writable: new WritableStream(),
      failure: null,
    });
    shouldResetSessionMock.mockReturnValue(false);

    const connection = new SessionConnection({
      runtime: {
        applyBatch: async () => {
          throw stop;
        },
      } as any,
      mayu: { setWriter: vi.fn(), clearWriter: vi.fn() } as any,
      endpoint: "/.mayu/session/test",
      sleep: async () => {
        throw stop;
      },
    });

    const running = connection.run();
    await Promise.resolve();

    expect(updateConnectionStatusMock).toHaveBeenCalledWith("transferring");
    expect(updateConnectionStatusMock).not.toHaveBeenCalledWith("connected");

    resolveInput(
      new ReadableStream({
        start(controller) {
          controller.enqueue(encode([[]]));
          controller.close();
        },
      }),
    );

    await expect(running).rejects.toBe(stop);

    expect(
      updateConnectionStatusMock.mock.calls.map(([status]) => status),
    ).toEqual(["transferring", "connected", "disconnected"]);
  });

  it("does not report a disconnect while establishing the first stream", async () => {
    let resolveInput!: (stream: ReadableStream<Uint8Array>) => void;
    const input = new Promise<ReadableStream<Uint8Array>>((resolve) => {
      resolveInput = resolve;
    });
    const stop = new Error("stop test loop");

    initInputStreamMock.mockReturnValueOnce(input);
    initCallbackStreamMock.mockReturnValue({
      writable: new WritableStream(),
      failure: null,
    });

    const connection = new SessionConnection({
      runtime: { applyBatch: vi.fn() } as any,
      mayu: { setWriter: vi.fn(), clearWriter: vi.fn() } as any,
      endpoint: "/.mayu/session/test",
      sleep: async () => {
        throw stop;
      },
    });

    const running = connection.run();
    await Promise.resolve();

    expect(updateConnectionStatusMock).not.toHaveBeenCalled();

    resolveInput(
      new ReadableStream({
        start(controller) {
          controller.close();
        },
      }),
    );

    await expect(running).rejects.toBe(stop);
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

  it("starts counting failures again after a stream connects", async () => {
    const stop = new Error("stop test loop");
    const callbackError = new Error("callback stream failed");
    initInputStreamMock
      .mockRejectedValueOnce(new Error("stream down"))
      .mockRejectedValueOnce(new Error("stream down"))
      .mockResolvedValueOnce(
        new ReadableStream({
          start(controller) {
            controller.enqueue(encode([[]]));
          },
        }),
      );
    let failCallback!: (error: Error) => void;
    // Only the third, successful attempt gets as far as the callback stream.
    initCallbackStreamMock.mockReturnValueOnce({
      writable: new WritableStream(),
      failure: new Promise<never>((_resolve, reject) => {
        failCallback = reject;
      }),
    });
    shouldResetSessionMock.mockReturnValue(false);
    const runtime = {
      applyBatch: vi.fn(async () => failCallback(callbackError)),
    };
    const sleepMock = vi
      .fn()
      .mockResolvedValueOnce(undefined)
      .mockResolvedValueOnce(undefined)
      .mockRejectedValueOnce(stop);

    const connection = new SessionConnection({
      runtime: runtime as any,
      mayu: { setWriter: vi.fn(), clearWriter: vi.fn() } as any,
      endpoint: "/.mayu/session/test",
      sleep: sleepMock,
    });

    await expect(connection.run()).rejects.toBe(stop);

    expect(runtime.applyBatch).toHaveBeenCalledOnce();
    expect(sleepMock.mock.calls.map(([delay]) => delay)).toEqual([
      1000, 2000, 1000,
    ]);
  });

  it("keeps counting attempts while the server keeps closing new streams", async () => {
    const stop = new Error("stop test loop");
    vi.spyOn(Date, "now").mockReturnValue(10_000);
    initInputStreamMock.mockImplementation(
      async () =>
        new ReadableStream({
          start(controller) {
            controller.enqueue(encode([[]]));
            controller.close();
          },
        }),
    );
    // A fresh stream per attempt: an aborted one would fail the next pipeline
    // and turn the clean close into an error.
    initCallbackStreamMock.mockImplementation(() => ({
      writable: new WritableStream(),
      failure: null,
    }));
    const sleepMock = vi
      .fn()
      .mockResolvedValueOnce(undefined)
      .mockRejectedValueOnce(stop);

    const connection = new SessionConnection({
      runtime: { applyBatch: vi.fn() } as any,
      mayu: { setWriter: vi.fn(), clearWriter: vi.fn() } as any,
      endpoint: "/.mayu/session/test",
      sleep: sleepMock,
    });

    await expect(connection.run()).rejects.toBe(stop);

    expect(
      updateReconnectStatusMock.mock.calls
        .map(([status]) => status)
        .filter((status) => status?.retryAt),
    ).toEqual([
      { attempt: 1, retryAt: 11_000 },
      { attempt: 2, retryAt: 12_000 },
    ]);
  });

  it("keeps reporting a transfer while reconnect attempts fail", async () => {
    setTransferState(new Blob(["encrypted state"]));
    initInputStreamMock.mockRejectedValue(new Error("Server is stopping"));
    shouldResetSessionMock.mockReturnValue(false);
    const stop = new Error("stop test loop");
    const sleepMock = vi
      .fn()
      .mockResolvedValueOnce(undefined)
      .mockRejectedValueOnce(stop);
    const connection = new SessionConnection({
      runtime: { applyBatch: vi.fn() } as any,
      mayu: { setWriter: vi.fn(), clearWriter: vi.fn() } as any,
      endpoint: "/.mayu/session/test",
      sleep: sleepMock,
    });

    await expect(connection.run()).rejects.toBe(stop);

    expect(
      updateConnectionStatusMock.mock.calls.map(([status]) => status),
    ).toEqual(["transferring", "transferring", "transferring", "transferring"]);
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
