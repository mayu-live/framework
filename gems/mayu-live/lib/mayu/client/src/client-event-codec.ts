import { encode } from "@msgpack/msgpack";

import type { ClientEvent } from "./protocol";

export const CLIENT_EVENT_COMPRESSION_THRESHOLD = 512;
export const CLIENT_EVENT_FRAME_HEADER_BYTES = 5;
export const CLIENT_EVENT_ENCODING_RAW = 0;
export const CLIENT_EVENT_ENCODING_DEFLATE_RAW = 1;

async function deflateRaw(input: Uint8Array): Promise<Uint8Array> {
  const compression = new CompressionStream("deflate-raw");
  const output = new Response(compression.readable).arrayBuffer();
  const writer = compression.writable.getWriter();

  await writer.write(input);
  await writer.close();

  return new Uint8Array(await output);
}

function frame(encoding: number, payload: Uint8Array): Uint8Array {
  const framed = new Uint8Array(
    CLIENT_EVENT_FRAME_HEADER_BYTES + payload.byteLength,
  );
  const view = new DataView(framed.buffer);

  view.setUint8(0, encoding);
  view.setUint32(1, payload.byteLength);
  framed.set(payload, CLIENT_EVENT_FRAME_HEADER_BYTES);

  return framed;
}

export async function encodeClientEvent(
  event: ClientEvent,
  compressionThreshold = CLIENT_EVENT_COMPRESSION_THRESHOLD,
): Promise<Uint8Array> {
  const encoded = encode(event);
  if (encoded.byteLength < compressionThreshold) {
    return frame(CLIENT_EVENT_ENCODING_RAW, encoded);
  }

  const compressed = await deflateRaw(encoded);

  return compressed.byteLength < encoded.byteLength
    ? frame(CLIENT_EVENT_ENCODING_DEFLATE_RAW, compressed)
    : frame(CLIENT_EVENT_ENCODING_RAW, encoded);
}

export class ClientEventEncoderStream extends TransformStream<
  ClientEvent,
  Uint8Array
> {
  constructor(compressionThreshold = CLIENT_EVENT_COMPRESSION_THRESHOLD) {
    super({
      async transform(event, controller) {
        controller.enqueue(
          await encodeClientEvent(event, compressionThreshold),
        );
      },
    });
  }
}
