import type Outbox from "../connection/outbox";

type PendingInspect = {
  resolve: (result: unknown) => void;
  reject: (error: Error) => void;
  timer: ReturnType<typeof setTimeout>;
};

// Events are dropped rather than replayed across disconnects, so an inspect
// request may never be answered.
const INSPECT_TIMEOUT = 5000;

// Questions from the devtools extension to the server's inspector. Loaded
// only when the extension is present.
export default class Inspect {
  #outbox: Outbox;
  #sequence = 0;
  #pending = new Map<string, PendingInspect>();

  constructor(outbox: Outbox) {
    this.#outbox = outbox;
  }

  dispose() {
    for (const id of this.#pending.keys()) {
      this.#settle(id, undefined, new Error("Mayu was disposed"));
    }
  }

  // The answer to a query, from an InspectResult command.
  resolve(id: string, result: unknown) {
    this.#settle(id, result);
  }

  // Asks the server's devtools inspector a question. Resolves with its
  // answer, which is null when the server has no inspector.
  inspect(query: Record<string, unknown>): Promise<unknown> {
    const id = `${++this.#sequence}`;
    const promise = new Promise<unknown>((resolve, reject) => {
      const timer = setTimeout(
        () => this.#settle(id, undefined, new Error("Inspect timed out")),
        INSPECT_TIMEOUT,
      );
      this.#pending.set(id, { resolve, reject, timer });
    });

    void this.#outbox.send(["Inspect", id, query]).then((wrote) => {
      if (!wrote) {
        this.#settle(id, undefined, new Error("Inspect not sent"));
      }
    });

    return promise;
  }

  #settle(id: string, result: unknown, error?: Error) {
    const pending = this.#pending.get(id);
    if (!pending) return;

    this.#pending.delete(id);
    clearTimeout(pending.timer);

    if (error) {
      pending.reject(error);
    } else {
      pending.resolve(result);
    }
  }
}
