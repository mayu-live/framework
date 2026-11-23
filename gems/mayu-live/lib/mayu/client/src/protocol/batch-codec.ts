import type { Batch } from "./commands";
import { decode } from "./msgpack";

const FRAME_HEADER_BYTES = 4;

function concat(chunks: Uint8Array[], size: number) {
  const bytes = new Uint8Array(size);
  let offset = 0;

  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }

  return bytes;
}

// The command stream is a sequence of frames: four bytes holding the length
// of the payload, big-endian, then one batch as MessagePack. Yields each
// batch once its whole frame has arrived, and throws if the stream ends in
// the middle of one.
export async function* decodeBatches(
  stream: ReadableStream<Uint8Array>,
): AsyncGenerator<Batch> {
  const reader = stream.getReader();
  // The chunks not yet decoded, and how many bytes it takes to go on.
  let pending: Uint8Array[] = [];
  let size = 0;
  let needed = FRAME_HEADER_BYTES;

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      pending.push(value);
      size += value.length;
      if (size < needed) continue;

      const bytes = pending.length === 1 ? pending[0] : concat(pending, size);
      const view = new DataView(
        bytes.buffer,
        bytes.byteOffset,
        bytes.byteLength,
      );
      let offset = 0;

      while (true) {
        const available = size - offset;
        needed = FRAME_HEADER_BYTES;
        if (available < needed) break;

        needed += view.getUint32(offset);
        if (available < needed) break;

        const start = offset + FRAME_HEADER_BYTES;
        offset += needed;
        yield decode(bytes.subarray(start, offset)) as Batch;
      }

      pending = offset < size ? [bytes.subarray(offset)] : [];
      size -= offset;
    }

    if (size > 0) throw new Error("Command stream ended inside a frame");
  } finally {
    reader.releaseLock();
  }
}
