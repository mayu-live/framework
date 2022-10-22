import { decodeMultiStream, ExtensionCodec } from "@msgpack/msgpack";
import { stringifyJSON, retry, sleep } from "./utils";
import DecompressionStreamPolyfill from "./DecompressionStream";
import { MimeTypes } from "./MimeTypes";

async function createDecompressionStream(): Promise<
  DecompressionStream | TransformStream<Uint8Array, Uint8Array>
> {
  if (typeof DecompressionStream !== "undefined") {
    console.warn("Using standard DecompressionStream");
    return new DecompressionStream("deflate");
  }

  console.warn("Loading DecompressionStream polyfill");

  const createDecompressionStreamPolyfill = (
    await import("./createDecompressionStreamPolyfill")
  ).default;

  console.warn("Using DecompressionStream polyfill");

  return createDecompressionStreamPolyfill();
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

  const decompressionStream = await createDecompressionStream();

  return res.body.pipeThrough(decompressionStream);
}

type ServerMessage = [id: string, event: string, payload: any];
type SessionStreamMessage = [string, any];

export async function* sessionStream(
  sessionId: string
): AsyncGenerator<SessionStreamMessage> {
  let isRunning = true;
  let encryptedState: Blob | undefined = undefined;
  let isConnected = false;
  const extensionCodec = createExtensionCodec();

  let res = await fetch(`/__mayu/session/${sessionId}/init`, {
    method: "POST",
  });

  while (isRunning) {
    try {
      const stream = await retry(() => startStream(res));

      try {
        for await (const message of decodeMultiStream(stream, {
          extensionCodec,
        })) {
          const [_id, event, payload] = message as ServerMessage;

          if (!isConnected) {
            isConnected = true;
            yield ["system.connected", {}];
          }

          if (encryptedState) {
            console.warn("Clearing encryptedState");
            encryptedState = undefined;
          }

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
                    instance: payload.instance,
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
      } catch (e) {
        console.error(e);
      }

      isConnected = false;

      yield ["system.disconnected", { transferring: !!encryptedState }];

      res = await retry(() =>
        fetch(`/__mayu/session/${sessionId}/resume`, {
          method: "POST",
          headers: { "content-type": MimeTypes.MAYU_SESSION },
          body: encryptedState,
        })
      );
    } catch (e) {
      console.error(e);
      await sleep(1000);
    }
  }
}

async function postCallback(sessionId: string, callbackId: string, data: any) {
  return fetch(`/__mayu/session/${sessionId}/${callbackId}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: stringifyJSON(data),
  });
}
