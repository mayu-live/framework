import { describe, expect, it } from "vitest";

import { decodeBatches } from "./batch-codec";
import type { NumberedBatch } from "./commands";
import { encode } from "./msgpack";

function frame(batch: NumberedBatch) {
  const payload = encode(batch);
  const framed = new Uint8Array(4 + payload.length);
  new DataView(framed.buffer).setUint32(0, payload.length);
  framed.set(payload, 4);
  return framed;
}

function join(...parts: Uint8Array[]) {
  const bytes = new Uint8Array(
    parts.reduce((size, part) => size + part.length, 0),
  );
  let offset = 0;
  for (const part of parts) {
    bytes.set(part, offset);
    offset += part.length;
  }
  return bytes;
}

function streamOf(...chunks: Uint8Array[]) {
  return new ReadableStream<Uint8Array>({
    start(controller) {
      for (const chunk of chunks) controller.enqueue(chunk);
      controller.close();
    },
  });
}

async function collect(stream: ReadableStream<Uint8Array>) {
  const batches: NumberedBatch[] = [];
  for await (const batch of decodeBatches(stream)) batches.push(batch);
  return batches;
}

const BATCHES: NumberedBatch[] = [
  [1, [["Pong", 1]]],
  [2, []],
  [
    3,
    [
      ["SetTextContent", "v1", "Smörgåsbord ✓"],
      ["AddClass", "v2", ["a", "b"]],
    ],
  ],
  [
    70_000,
    [["CreateTree", `<p>${"x".repeat(500)}</p>`, [{ id: "v3", name: "P" }]]],
  ],
];

describe("decodeBatches", () => {
  it("yields nothing for an empty stream", async () => {
    expect(await collect(streamOf())).toEqual([]);
  });

  it("decodes one frame per chunk", async () => {
    expect(await collect(streamOf(...BATCHES.map(frame)))).toEqual(BATCHES);
  });

  it("decodes several frames from one chunk", async () => {
    expect(await collect(streamOf(join(...BATCHES.map(frame))))).toEqual(
      BATCHES,
    );
  });

  it("decodes frames split at every possible boundary", async () => {
    const bytes = join(...BATCHES.map(frame));

    for (let split = 0; split <= bytes.length; split++) {
      const batches = await collect(
        streamOf(bytes.subarray(0, split), bytes.subarray(split)),
      );
      expect(batches).toEqual(BATCHES);
    }
  });

  it("decodes frames that arrive a few bytes at a time", async () => {
    const bytes = join(...BATCHES.map(frame));
    const chunks = [];
    for (let offset = 0; offset < bytes.length; offset += 3) {
      chunks.push(bytes.subarray(offset, offset + 3));
    }

    expect(await collect(streamOf(...chunks))).toEqual(BATCHES);
  });

  it("yields each batch as soon as its frame is complete", async () => {
    let controller!: ReadableStreamDefaultController<Uint8Array>;
    const stream = new ReadableStream<Uint8Array>({
      start(streamController) {
        controller = streamController;
      },
    });
    const batches = decodeBatches(stream);

    controller.enqueue(frame(BATCHES[0]));
    expect((await batches.next()).value).toEqual(BATCHES[0]);

    const next = batches.next();
    controller.enqueue(frame(BATCHES[2]).subarray(0, 5));
    controller.enqueue(frame(BATCHES[2]).subarray(5));
    expect((await next).value).toEqual(BATCHES[2]);

    controller.close();
    expect((await batches.next()).done).toBe(true);
  });

  it("fails when the stream ends inside a frame", async () => {
    const bytes = join(...BATCHES.map(frame));

    for (const length of [1, 3, 4, 7, bytes.length - 1]) {
      await expect(
        collect(streamOf(bytes.subarray(0, length))),
      ).rejects.toThrow("Command stream ended inside a frame");
    }
  });

  it("releases the stream when the consumer stops early", async () => {
    const stream = streamOf(...BATCHES.map(frame));

    for await (const _batch of decodeBatches(stream)) break;

    expect(stream.locked).toBe(false);
  });
});
