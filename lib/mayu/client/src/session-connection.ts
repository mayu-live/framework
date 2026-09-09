import { decodeMultiStream, ExtensionCodec } from "@msgpack/msgpack";

import Runtime from "./runtime.js";
import {
  initInputStream,
  initCallbackStream,
  JSONEncoderStream,
  StreamError,
} from "./stream.js";
import { SESSION_MIME_TYPE } from "./constants";
import { updateConnectionStatus } from "./ping";
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
      return new Blob([buffer], { type: SESSION_MIME_TYPE });
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

    while (true) {
      const abortController = new AbortController();
      let callbackWriter: WritableStreamDefaultWriter<any> | null = null;
      let callbackPipeline: Promise<void> | null = null;

      try {
        const state = getTransferState();

        updateConnectionStatus(state ? "transferring" : "disconnected");

        const input = await initInputStream(
          this.#endpoint,
          state,
          abortController.signal,
        );
        setTransferState(null);

        const callbackStream = new TransformStream();
        callbackWriter = callbackStream.writable.getWriter();
        this.#mayu.setWriter(callbackWriter);
        const output = initCallbackStream(
          this.#endpoint,
          abortController.signal,
        );

        failures = 0;

        callbackPipeline = callbackStream.readable
          .pipeThrough(new JSONEncoderStream())
          .pipeThrough(new TextEncoderStream())
          .pipeTo(output)
          .catch((error) => {
            if (!isAbortError(error)) {
              console.error("Callback pipeline error", error);
            }
          });

        updateConnectionStatus("connected");

        for await (const patch of decodeMultiStream(input, {
          extensionCodec,
        })) {
          updateConnectionStatus("connected");

          if (
            Array.isArray(patch) &&
            patch.some(
              (entry) => Array.isArray(entry) && entry[0] === "TransferFailed",
            )
          ) {
            throw new StreamError("Session transfer failed", "TRANSFER_FAILED");
          }

          try {
            await this.#runtime.apply(patch as any);
          } catch (error) {
            console.error(error);
          }
        }
      } catch (error: unknown) {
        failures += 1;
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
        await this.#sleep(sleepTime);
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
          await callbackPipeline;
        }
      }
    }
  }
}
