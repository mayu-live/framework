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
};

export default class SessionConnection {
  #runtime: Runtime;
  #mayu: Mayu;
  #endpoint: string;

  constructor({ runtime, mayu, endpoint }: SessionConnectionOptions) {
    this.#runtime = runtime;
    this.#mayu = mayu;
    this.#endpoint = endpoint;
  }

  async run() {
    const extensionCodec = createExtensionCodec();
    let failures = 0;

    while (true) {
      try {
        const state = getTransferState();

        updateConnectionStatus(state ? "transferring" : "disconnected");

        const input = await initInputStream(this.#endpoint, state);
        setTransferState(null);

        const callbackStream = new TransformStream();
        this.#mayu.setWriter(callbackStream.writable.getWriter());
        const output = initCallbackStream(this.#endpoint);

        failures = 0;

        callbackStream.readable
          .pipeThrough(new JSONEncoderStream())
          .pipeThrough(new TextEncoderStream())
          .pipeTo(output);

        updateConnectionStatus("connected");

        for await (const patch of decodeMultiStream(input, {
          extensionCodec,
        })) {
          updateConnectionStatus("connected");

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
        await sleep(sleepTime);
      }
    }
  }
}
