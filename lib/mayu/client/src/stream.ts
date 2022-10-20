import { addExtension, Unpackr } from "msgpackr";
import { inflate } from "pako";
import "./polyfill-readableStreamAsyncGenerator";

addExtension({
  Class: Blob,
  type: 0x01,
  pack() {
    throw new Error("Not implemented");
  },
  unpack(buffer: Uint8Array) {
    return new Blob([buffer], { type: "application/vnd.mayu.session" });
  },
});

const MIME_TYPES = {
  MAYU_SESSION: "application/vnd.mayu.session",
  MAYU_STREAM: "application/vnd.mayu.eventstream",
};

import { sleep, stringifyJSON, retry } from "./utils";

async function startStream(res: Response) {
  if (!res.ok) {
    throw new Error("res is not ok");
  }

  if (!res.body) {
    throw new Error("body is null");
  }

  const reader = res.body.getReader() as any;

  return new ReadableStream({
    start(controller) {
      const unpackr = new Unpackr({ useRecords: false });

      async function push() {
        try {
          const { done, value } = (await reader.read()) as {
            done: boolean;
            value: Uint8Array;
          };

          if (done) {
            controller.close();
            return;
          }

          const messages = unpackr.unpackMultiple(inflate(value));

          for (const msg of messages) {
            controller.enqueue(msg);
          }

          push();
        } catch (e) {
          console.error("Streaming error:", e);
          // await sleep(1000);
          controller.close();
        }
      }

      push();
    },

    cancel(reason) {
      console.error("Cancelled", reason);
    },
  });
}

type SessionStreamMessage = [string, any];

export async function* sessionStream(
  sessionId: string
): AsyncGenerator<SessionStreamMessage> {
  let isRunning = true;
  let encryptedState: Blob | undefined = undefined;

  let res = await fetch(`/__mayu/session/${sessionId}/init`, {
    method: "POST",
  });

  try {
    while (isRunning) {
      const stream = (await retry(() => startStream(res))) as any;

      yield ["system.connected", {}];

      encryptedState = undefined;

      for await (const [id, event, payload] of stream) {
        try {
          switch (event) {
            case "session.transfer":
              yield ["session.transfer", {}];
              encryptedState = payload;
              break;
            case "pong":
              yield [
                "ping",
                {
                  values: {
                    client: new Date().getTime() - Number(payload.pong),
                    server: payload.server,
                  },
                  region: payload.region,
                },
              ];
              break;
            case "ping":
              postCallback(sessionId, "ping", {
                pong: payload,
                ping: new Date().getTime(),
              });
              break;
            default:
              yield [event, payload];
          }
        } catch (e) {
          console.error(e);
        }
      }

      yield ["system.disconnected", {}];

      res = await retry(() =>
        fetch(`/__mayu/session/${sessionId}/resume`, {
          method: "POST",
          headers: { "content-type": MIME_TYPES.MAYU_SESSION },
          body: encryptedState,
        })
      );
    }
  } catch (e) {
    console.error(e);
  }
}

async function postCallback(sessionId: string, callbackId: string, data: any) {
  return fetch(`/__mayu/session/${sessionId}/${callbackId}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: stringifyJSON(data),
  });
}
