import { CONTINUOUS_EVENT_INTERVAL_MS } from "./constants";

type ThrottleEntry = {
  timeout: ReturnType<typeof setTimeout>;
  pending: (() => void) | null;
};

// Leading and trailing throttle per key. The first call runs right away and
// opens a window; calls inside the window replace each other, and the latest
// one runs when the window closes and opens the next window.
export default class Throttle {
  #entries = new Map<string, ThrottleEntry>();
  #interval: number;

  constructor(interval: number = CONTINUOUS_EVENT_INTERVAL_MS) {
    this.#interval = interval;
  }

  call(key: string, cb: () => void) {
    const entry = this.#entries.get(key);

    if (entry) {
      entry.pending = cb;
      return;
    }

    this.#open(key);
    cb();
  }

  // Runs every pending call now, so that they are sent before whatever
  // the caller is about to send.
  flush() {
    const pending = this.#takeAll();
    for (const cb of pending) cb();
  }

  clear() {
    this.#takeAll();
  }

  #open(key: string) {
    this.#entries.set(key, {
      timeout: setTimeout(() => this.#close(key), this.#interval),
      pending: null,
    });
  }

  #close(key: string) {
    const entry = this.#entries.get(key);
    this.#entries.delete(key);

    if (!entry?.pending) return;

    this.#open(key);
    entry.pending();
  }

  #takeAll() {
    const pending: (() => void)[] = [];

    for (const entry of this.#entries.values()) {
      clearTimeout(entry.timeout);
      if (entry.pending) pending.push(entry.pending);
    }

    this.#entries.clear();
    return pending;
  }
}
