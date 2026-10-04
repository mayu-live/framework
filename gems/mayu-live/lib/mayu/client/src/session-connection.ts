import { decodeMultiStream, ExtensionCodec } from "@msgpack/msgpack";

import Runtime from "./runtime.js";
import { initInputStream, initCallbackStream, StreamError } from "./stream.js";
import { ClientEventEncoderStream } from "./client-event-codec.js";
import { SESSION_MIME_TYPE } from "./constants";
import { updateConnectionStatus, updateReconnectStatus } from "./ping";
import type { Batch, ClientEvent } from "./protocol";
import { getTransferState, setTransferState } from "./transfer";
import {
  getErrorMessage,
  resetSessionEntirely,
  shouldResetSession,
} from "./session-recovery.js";
import Mayu from "./mayu.js";

async function sleep(milliseconds: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, milliseconds));
}

function createExtensionCodec() {
  const extensionCodec = new ExtensionCodec();

  extensionCodec.register({
    type: 0x01,
    encode() {
      throw new Error("Not implemented");
    },
    decode(buffer) {
      return new Blob([buffer.slice()], { type: SESSION_MIME_TYPE });
    },
  });

  return extensionCodec;
}

type SessionConnectionOptions = {
  runtime: Runtime;
  mayu: Mayu;
  endpoint: string;
  sleep?: (milliseconds: number) => Promise<void>;
};

// A held transfer state means the session is waiting to resume on another
// server. Deriving the status from it keeps the dialog title stable while
// retries fail, instead of flipping between the two on every attempt.
function reportDisconnected() {
  updateConnectionStatus(getTransferState() ? "transferring" : "disconnected");
}

function isAbortError(error: unknown): boolean {
  return error instanceof Error && error.name === "AbortError";
}

export default class SessionConnection {
  #runtime: Runtime;
  #mayu: Mayu;
  #endpoint: string;
  #sleep: (milliseconds: number) => Promise<void>;

  constructor({
    runtime,
    mayu,
    endpoint,
    sleep: sleepFn,
  }: SessionConnectionOptions) {
    this.#runtime = runtime;
    this.#mayu = mayu;
    this.#endpoint = endpoint;
    this.#sleep = sleepFn || sleep;
  }

  async run() {
    const extensionCodec = createExtensionCodec();
    let failures = 0;
    let consecutiveEofs = 0;
    let hasConnected = false;

    while (true) {
      // Count attempts the same way the retry delays back off, so the number
      // shown next to a countdown always matches the delay being waited out.
      const attempt = failures + Math.max(0, consecutiveEofs - 1) + 1;
      const abortController = new AbortController();
      let callbackWriter: WritableStreamDefaultWriter<ClientEvent> | null =
        null;
      let callbackPipeline: Promise<void> | null = null;
      let retryDelay: number | null = null;

      try {
        const state = getTransferState();

        // The initial connection is expected. Reporting it as disconnected
        // briefly opens the recovery dialog before the first stream succeeds.
        if (state || hasConnected) {
          reportDisconnected();
        }
        updateReconnectStatus({ attempt, retryAt: null });

        const input = await initInputStream(
          this.#endpoint,
          state,
          abortController.signal,
        );
        setTransferState(null);

        const callbackStream = new TransformStream<ClientEvent, ClientEvent>();
        callbackWriter = callbackStream.writable.getWriter();
        this.#mayu.setWriter(callbackWriter);
        const output = initCallbackStream(
          this.#endpoint,
          abortController.signal,
        );

        callbackPipeline = callbackStream.readable
          .pipeThrough(new ClientEventEncoderStream())
          .pipeTo(output.writable);
        void callbackPipeline.catch(() => undefined);

        const consumeInput = async () => {
          for await (const decoded of decodeMultiStream(input, {
            extensionCodec,
          })) {
            updateConnectionStatus("connected");
            updateReconnectStatus(null);
            hasConnected = true;
            // A working stream ends the failure streak. consecutiveEofs is
            // kept, since it backs off servers that close every new stream.
            failures = 0;
            const batch = decoded as Batch;

            if (batch.some((command) => command[0] === "TransferFailed")) {
              throw new StreamError(
                "Session transfer failed",
                "TRANSFER_FAILED",
              );
            }

            await this.#runtime.applyBatch(batch);
          }

          return "eof" as const;
        };

        const result = await Promise.race([
          consumeInput(),
          output.failure ?? new Promise<never>(() => undefined),
          callbackPipeline.then(() => "callback-eof" as const),
        ]);

        if (result === "callback-eof") {
          throw new StreamError("Callback pipeline ended");
        }

        failures = 0;
        consecutiveEofs += 1;
        retryDelay = Math.min(10_000, 1000 * Math.max(0, consecutiveEofs - 1));
        reportDisconnected();
      } catch (error: unknown) {
        consecutiveEofs = 0;
        failures += 1;
        reportDisconnected();
        const message = getErrorMessage(error);

        if (error instanceof StreamError) {
          console.error("StreamError", error.message);
        } else {
          console.error(error);
        }

        if (shouldResetSession(error)) {
          console.warn("Resetting session because of:", message);

          try {
            this.#endpoint = await resetSessionEntirely();
            failures = 0;
            continue;
          } catch (resetError) {
            console.error("Session reset failed", resetError);
          }
        }

        const sleepTime = Math.min(10_000, 1000 * failures);
        console.info(`Attempting to reconnect in`, sleepTime, "ms");
        retryDelay = sleepTime;
      } finally {
        abortController.abort();
        this.#mayu.clearWriter();

        if (callbackWriter) {
          try {
            await callbackWriter.abort();
          } catch (_error) {
          } finally {
            callbackWriter.releaseLock();
          }
        }

        if (callbackPipeline) {
          await callbackPipeline.catch(() => undefined);
        }
      }

      if (retryDelay && retryDelay > 0) {
        updateReconnectStatus({ attempt, retryAt: Date.now() + retryDelay });
        await this.#sleep(retryDelay);
      }
    }
  }
}
