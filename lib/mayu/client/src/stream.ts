import { inflate } from "pako";
import { Inflate } from "fflate";
import { decodeMultiStream, ExtensionCodec } from "@msgpack/msgpack";
import "./polyfill-readableStreamAsyncGenerator";
import { QuickReader, A } from "quickreader";

const MIME_TYPES = {
  MAYU_SESSION: "application/vnd.mayu.session",
  MAYU_STREAM: "application/vnd.mayu.eventstream",
};

import { stringifyJSON, retry } from "./utils";

function createPacketReadableStream(stream: ReadableStream) {
  const reader = new QuickReader(stream);

  return new ReadableStream<Uint8Array>({
    async pull(controller) {
      if (reader.eof) {
        controller.close();
        return;
      }

      console.time("Reading packet");
      const length = reader.u32be() ?? (await A);
      console.log("Packet length:", length);
      const packet = reader.bytes(length) ?? (await A);
      console.log("Packet read:", packet.byteLength);
      console.timeEnd("Reading packet");
      controller.enqueue(packet);
    },
  });
}

function createInflateTransformStream() {
  let decompressor: Inflate;

  return new TransformStream<Uint8Array, Uint8Array>({
    async start(controller) {
      decompressor = new Inflate((chunk: Uint8Array, final: boolean) => {
        if (final) {
          controller.terminate();
        } else {
          controller.enqueue(chunk);
        }
      });
    },
    async transform(chunk) {
      decompressor.push(chunk, false);
    },
    flush() {
      decompressor.push(new Uint8Array(), true);
    },
  });
}

function createExtensionCodec() {
  const extensionCodec = new ExtensionCodec();

  extensionCodec.register({
    type: 0x01,
    encode() {
      throw new Error("Not implemented");
    },
    decode(buffer: Uint8Array) {
      return new Blob([buffer], { type: "application/vnd.mayu.session" });
    },
  });

  return extensionCodec;
}

async function startStream(res: Response) {
  if (!res.ok) {
    throw new Error("res is not ok");
  }

  if (!res.body) {
    throw new Error("body is null");
  }

  // const decompressor = new DecompressionStream("deflate")
  return res.body.pipeThrough(createInflateTransformStream());
}

async function* startStream2(res: Response) {
  const stream = await retry(() => startStream(res));
  const extensionCodec = createExtensionCodec();

  for await (const msg of decodeMultiStream(stream, { extensionCodec })) {
    yield msg as ServerMessage;
  }
}

type ServerMessage = [id: string, event: string, payload: any];
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
      const stream = startStream2(res);

      yield ["system.connected", {}];

      console.warn("Resetting encryptedState");
      encryptedState = undefined;

      for await (const [_id, event, payload] of stream) {
        try {
          switch (event) {
            case "session.transfer":
              yield ["session.transfer", {}];
              encryptedState = payload;
              console.warn("Setting encryptedState", payload);
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
