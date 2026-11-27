import { UnreadableBatchError } from "../protocol/batch-codec";
import type { Batch, CommandHandlers } from "../protocol/commands";
import { updateConnectionStatus, updateReconnectStatus } from "../ui/status";
import runAttempt from "./attempt";
import type { EarlyStream } from "./command-stream";
import Backoff from "./backoff";
import type Outbox from "./outbox";
import {
  getErrorMessage,
  resetSessionEntirely,
  shouldResetSession,
} from "./recovery";
import { StreamError } from "./stream-error";

// Sent as the last batch when the page can't say where it is. It is no
// number the server gave out, so the server answers with the whole page.
const LOST_TRACK = -1;

async function sleep(milliseconds: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, milliseconds));
}

type SessionConnectionOptions = {
  endpoint: string;
  outbox: Pick<Outbox, "attach" | "detach" | "acknowledge">;
  applyBatch: (batch: Batch) => Promise<void>;
  transferState?: Blob | null;
  // The request init.ts sent for the command stream, for the first attempt.
  early?: EarlyStream | null;
  sleep?: (milliseconds: number) => Promise<void>;
  reload?: () => void;
};

// Keeps the session connected: runs one connection attempt after another,
// with a delay in between that grows while attempts keep failing, and
// replaces the session with a new one when the server no longer has it.
export default class SessionConnection {
  #endpoint: string;
  #outbox: Pick<Outbox, "attach" | "detach" | "acknowledge">;
  #applyBatch: (batch: Batch) => Promise<void>;
  #sleep: (milliseconds: number) => Promise<void>;
  #reload: () => void;
  // The encrypted session a stopping server handed over, held until another
  // server has resumed it.
  #transferState: Blob | null;
  // The number of the last batch applied, which the server resumes from
  // when the stream reconnects. Null when its numbers no longer mean
  // anything: before the first batch, and for a session that was replaced
  // or moved to another server.
  #lastBatch: number | null = null;
  // Set while the page may differ from what the server believes it shows.
  // A stream opened in that state asks for the whole page.
  #lostTrack = false;
  #early: EarlyStream | null;

  readonly handlers: CommandHandlers<"Transfer"> = {
    Transfer: (state) => {
      this.#transferState = state;
    },
  };

  constructor({
    endpoint,
    outbox,
    applyBatch,
    transferState = null,
    early = null,
    sleep: sleepFn,
    reload = () => location.reload(),
  }: SessionConnectionOptions) {
    this.#reload = reload;
    this.#early = early;
    this.#endpoint = endpoint;
    this.#outbox = outbox;
    this.#applyBatch = applyBatch;
    this.#transferState = transferState;
    this.#sleep = sleepFn || sleep;
  }

  get transferState() {
    return this.#transferState;
  }

  async run() {
    const backoff = new Backoff();
    let hasConnected = false;

    while (true) {
      const attempt = backoff.attempt;
      let retryDelay: number;

      try {
        // The initial connection is expected. Reporting it as disconnected
        // briefly opens the recovery dialog before the first stream succeeds.
        if (this.#transferState || hasConnected) {
          this.#reportDisconnected();
        }
        updateReconnectStatus({ attempt, retryAt: null });

        // The server that resumes a transferred session starts counting
        // from the beginning.
        if (this.#transferState) this.#applied(null);

        const early = this.#early;
        this.#early = null;

        await runAttempt({
          early,
          endpoint: this.#endpoint,
          transferState: this.#transferState,
          lastBatch: this.#lostTrack ? LOST_TRACK : this.#lastBatch,
          outbox: this.#outbox,
          onOpen: () => {
            this.#transferState = null;
          },
          onBatch: async (batch, seq) => {
            updateConnectionStatus("connected");
            updateReconnectStatus(null);
            hasConnected = true;
            backoff.streamWorked();

            // The server could not hand the session over. This ends the
            // stream whatever the error policy for commands is.
            if (batch.some((command) => command[0] === "TransferFailed")) {
              throw new StreamError(
                "Session transfer failed",
                "TRANSFER_FAILED",
              );
            }

            await this.#applyBatch(batch);
            this.#applied(seq);
          },
        });

        retryDelay = backoff.ended();
        this.#reportDisconnected();
      } catch (error: unknown) {
        backoff.failed();
        this.#reportDisconnected();

        if (error instanceof StreamError) {
          console.error("StreamError", error.message);
        } else {
          console.error(error);
        }

        // The server would send the same batch again. The whole page has
        // what that batch held.
        if (error instanceof UnreadableBatchError) this.#lostTrack = true;

        // This runtime and the server speak different versions, as when a
        // deploy replaced the server under an open page. The page that
        // server sends comes with a runtime it understands.
        if (
          error instanceof StreamError &&
          error.code === "PROTOCOL_MISMATCH"
        ) {
          this.#reload();
          return;
        }

        if (shouldResetSession(error)) {
          console.warn("Resetting session because of:", getErrorMessage(error));

          try {
            this.#endpoint = await resetSessionEntirely();
            this.#transferState = null;
            this.#lostTrack = false;
            this.#applied(null);
            backoff.sessionReset();
            continue;
          } catch (resetError) {
            console.error("Session reset failed", resetError);
          }
        }

        retryDelay = backoff.delay;
        console.info(`Attempting to reconnect in`, retryDelay, "ms");
      }

      if (retryDelay > 0) {
        updateReconnectStatus({ attempt, retryAt: Date.now() + retryDelay });
        await this.#sleep(retryDelay);
      }
    }
  }

  // A command could not be applied. If the request for the page is lost
  // with the connection, the next stream asks again.
  lostTrack() {
    this.#lostTrack = true;
  }

  // The server's page has replaced the document.
  resynced() {
    this.#lostTrack = false;
  }

  #applied(seq: number | null) {
    this.#lastBatch = seq;
    this.#outbox.acknowledge(seq);
  }

  // A held transfer state means the session is waiting to resume on another
  // server. Deriving the status from it keeps the dialog title stable while
  // retries fail, instead of flipping between the two on every attempt.
  #reportDisconnected() {
    updateConnectionStatus(
      this.#transferState ? "transferring" : "disconnected",
    );
  }
}
