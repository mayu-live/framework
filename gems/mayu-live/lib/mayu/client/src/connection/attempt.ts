import { decodeBatches } from "../protocol/batch-codec";
import type { Batch } from "../protocol/commands";
import { ClientEventEncoderStream } from "../protocol/event-codec";
import type { ClientEvent } from "../protocol/events";
import { openCommandStream } from "./command-stream";
import { openEventStream } from "./event-stream";
import type Outbox from "./outbox";
import { StreamError } from "./stream-error";

type AttemptOptions = {
  endpoint: string;
  // Encrypted session state to resume from, after a transfer.
  transferState: Blob | null;
  outbox: Pick<Outbox, "attach" | "detach">;
  // Called once the command stream is open.
  onOpen: () => void;
  // Called with every batch, in order. The next batch waits for it.
  onBatch: (batch: Batch) => Promise<void>;
};

// One connection to the server: opens the command stream and the event
// stream, applies batches until either stream ends, and tears both down.
// Resolves when the command stream ends cleanly and rejects on any failure,
// so that both directions always reconnect together.
export default async function runAttempt({
  endpoint,
  transferState,
  outbox,
  onOpen,
  onBatch,
}: AttemptOptions): Promise<void> {
  const abortController = new AbortController();
  let eventWriter: WritableStreamDefaultWriter<ClientEvent> | null = null;
  let eventPipeline: Promise<void> | null = null;

  try {
    const input = await openCommandStream(
      endpoint,
      transferState,
      abortController.signal,
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
      for await (const batch of decodeBatches(input)) {
        await onBatch(batch);
      }

      return "eof" as const;
    };

    const result = await Promise.race([
      consumeInput(),
      output.failure ?? new Promise<never>(() => undefined),
      eventPipeline.then(() => "event-eof" as const),
    ]);

    if (result === "event-eof") {
      throw new StreamError("Callback pipeline ended");
    }
  } finally {
    abortController.abort();
    outbox.detach();

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
