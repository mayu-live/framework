import { decodeMultiStream, ExtensionCodec } from "@msgpack/msgpack";
import { stringifyJSON, retry, FatalError, sleep } from "./utils";
import { MimeTypes } from "./MimeTypes";
import type MayuLogElement from "./custom-elements/mayu-log";
import logger from "./logger";
import DecompressionStream from "./DecompressionStream";

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

async function startStream(sessionId: string, encryptedState?: Blob) {
  const res = await resume(sessionId, encryptedState);

  if (!res.ok) {
    const text = await res.text();

    if (res.status == 503) {
      // Server is shutting down, so retry..
      throw new Error(`${res.status}: ${text}`);
    }

    throw new FatalError(`${res.status}: ${text}`);
  }

  if (!res.body) {
    throw new FatalError("body is null");
  }

  const decompressionStream = new DecompressionStream("deflate-raw");

  return res.body.pipeThrough(decompressionStream);
}

type ServerMessage = [id: string, event: string, payload: any];
type SessionStreamMessage = [string, any];

function resume(sessionId: string, encryptedState?: Blob) {
  if (!encryptedState) {
    return retry(() =>
      fetch(`/__mayu/session/${sessionId}/init`, {
        method: "POST",
      })
    );
  }

  return retry(() =>
    fetch(`/__mayu/session/${sessionId}/resume`, {
      method: "POST",
      headers: { "content-type": MimeTypes.MAYU_SESSION },
      body: encryptedState,
    })
  );
}

function errorMessage(e: any) {
  if (e instanceof Error) {
    return e.message;
  }

  if (typeof e === "string") {
    return e;
  }

  return String(e);
}

export async function* sessionStream(
  sessionId: string,
  logElement: MayuLogElement
): AsyncGenerator<SessionStreamMessage> {
  let isRunning = true;
  let encryptedState: Blob | undefined;
  let isConnected = false;
  const extensionCodec = createExtensionCodec();
  let reason: string | undefined;

  while (isRunning) {
    try {
      const stream = await retry(() => startStream(sessionId, encryptedState));

      try {
        for await (const message of decodeMultiStream(stream, {
          extensionCodec,
        })) {
          const [id, event, payload] = message as ServerMessage;

          // logElement.addEntry(id, event, payload);

          if (!isConnected) {
            isConnected = true;
            // logElement.addEntry("system", "connected", {});
            yield ["system.connected", {}];
          }

          if (encryptedState) {
            logger.info("Clearing encryptedState");
            encryptedState = undefined;
          }

          try {
            switch (event) {
              case "session.transfer":
                yield ["session.transfer", {}];
                encryptedState = payload;
                logger.info("Setting encryptedState", payload);
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
            reason = errorMessage(e);
            logger.error(e);
          }
        }
      } catch (e) {
        reason = errorMessage(e);
        logger.error(e);
      }

      isConnected = false;

      if (isRunning) {
        reason ||= "Stream ended unexpectedly";
      }

      yield ["system.disconnected", { transferring: !!encryptedState, reason }];
    } catch (e) {
      logger.error(e);

      if (e instanceof FatalError) {
        isRunning = false;
        isConnected = false;
        yield ["system.disconnected", { reason: e.message }];
        return;
      }

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
