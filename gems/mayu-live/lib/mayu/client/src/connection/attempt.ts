import { decodeBatches } from "../protocol/batch-codec";
import type { Batch } from "../protocol/commands";
import { ClientEventEncoderStream } from "../protocol/event-codec";
import type { ClientEvent } from "../protocol/events";
import { type EarlyStream, openCommandStream } from "./command-stream";
import { openEventStream } from "./event-stream";
import type Outbox from "./outbox";
import { StreamError } from "./stream-error";

type AttemptOptions = {
  endpoint: string;
  // Encrypted session state to resume from, after a transfer.
  transferState: Blob | null;
  // The last batch this page applied, when the server can pick up from it.
  lastBatch: number | null;
  // The request for the command stream, when it has been sent already.
  early?: EarlyStream | null;
  outbox: Pick<Outbox, "attach" | "detach">;
  // Called once the command stream is open.
  onOpen: () => void;
  // Called with every batch and its number, in order. The next batch
  // waits for it.
  onBatch: (batch: Batch, seq: number) => Promise<void>;
};

// One connection to the server: opens the command stream and the event
// stream, applies batches until either stream ends, and tears both down.
// No batch is applied after it has returned.
// Resolves when the command stream ends cleanly and rejects on any failure,
// so that both directions always reconnect together.
export default async function runAttempt({
  endpoint,
  transferState,
  lastBatch,
  early = null,
  outbox,
  onOpen,
  onBatch,
}: AttemptOptions): Promise<void> {
  const abortController = new AbortController();
  let eventWriter: WritableStreamDefaultWriter<ClientEvent> | null = null;
  let eventPipeline: Promise<void> | null = null;
  // The batch being applied right now.
  let applying = null as Promise<void> | null;
  let ended = false;

  try {
    const input = await openCommandStream(
      endpoint,
      transferState,
      abortController.signal,
      lastBatch,
      early,
    );
    onOpen();

    const events = new TransformStream<ClientEvent, ClientEvent>();
    eventWriter = events.writable.getWriter();
    outbox.attach(eventWriter);
    const output = openEventStream(endpoint, abortController.signal);

    eventPipeline = events.readable
      .pipeThrough(new ClientEventEncoderStream())
      .pipeTo(output.writable);
    void eventPipeline.catch(() => undefined);

    const consumeInput = async () => {
      for await (const [seq, batch] of decodeBatches(input)) {
        // The attempt is over. Batches that arrived with the last one
        // applied are left for the next stream, which gets them again.
        if (ended) break;
        applying = onBatch(batch, seq);
        await applying;
        applying = null;
      }

      return "eof" as const;
    };

    const consuming = consumeInput();
    void consuming.catch(() => undefined);

    const result = await Promise.race([
      consuming,
      output.failure ?? new Promise<never>(() => undefined),
      eventPipeline.then(() => "event-eof" as const),
    ]);

    if (result === "event-eof") {
      throw new StreamError("Callback pipeline ended");
    }
  } finally {
    ended = true;
    abortController.abort();
    outbox.detach();

    // A batch may still be on its way into the page. The next attempt tells
    // the server what this one applied, so it waits for that.
    await applying?.catch(() => undefined);

    if (eventWriter) {
      try {
        await eventWriter.abort();
      } catch (_error) {
      } finally {
        eventWriter.releaseLock();
      }
    }

    if (eventPipeline) {
      await eventPipeline.catch(() => undefined);
    }
  }
}
