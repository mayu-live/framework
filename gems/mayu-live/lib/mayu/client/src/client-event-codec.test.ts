import { decode } from "@msgpack/msgpack";
import { describe, expect, it } from "vitest";

import {
  CLIENT_EVENT_ENCODING_DEFLATE_RAW,
  CLIENT_EVENT_ENCODING_RAW,
  CLIENT_EVENT_FRAME_HEADER_BYTES,
  encodeClientEvent,
} from "./client-event-codec";
import type { ClientEvent } from "./protocol";

async function inflateRaw(input: Uint8Array): Promise<Uint8Array> {
  const decompression = new DecompressionStream("deflate-raw");
  const output = new Response(decompression.readable).arrayBuffer();
  const writer = decompression.writable.getWriter();

  await writer.write(input);
  await writer.close();

  return new Uint8Array(await output);
}

function unframe(frame: Uint8Array) {
  const view = new DataView(frame.buffer, frame.byteOffset, frame.byteLength);
  const encoding = view.getUint8(0);
  const length = view.getUint32(1);
  const payload = frame.subarray(CLIENT_EVENT_FRAME_HEADER_BYTES);

  expect(payload.byteLength).toBe(length);
  return { encoding, payload };
}

describe("client event codec", () => {
  it("encodes small events directly as compact MessagePack tuples", async () => {
    const event: ClientEvent = ["Ping", 123];
    const encoded = await encodeClientEvent(event);
    const frame = unframe(encoded);

    expect(frame.encoding).toBe(CLIENT_EVENT_ENCODING_RAW);
    expect(decode(frame.payload)).toEqual(event);
    expect(Array.from(encoded)).toEqual([
      0x00, 0x00, 0x00, 0x00, 0x07, 0x92, 0xa4, 0x50, 0x69, 0x6e, 0x67, 0x7b,
    ]);
  });

  it("compresses large events as independent frames", async () => {
    const event: ClientEvent = [
      "Callback",
      "listener",
      { target: { value: "Mayu ".repeat(1_000) } },
      123,
    ];
    const frame = unframe(await encodeClientEvent(event, 0));

    expect(frame.encoding).toBe(CLIENT_EVENT_ENCODING_DEFLATE_RAW);
    const inflated = await inflateRaw(frame.payload);
    expect(decode(inflated)).toEqual(event);
  });
});
