const MAX_DELAY = 10_000;
const STEP = 1_000;

// Decides how long to wait before the next connection attempt. Failures
// back off one second per failure in a row. A stream that ends cleanly is
// retried at once the first time, and backs off the same way when the
// server keeps closing every new stream.
export default class Backoff {
  #failures = 0;
  #consecutiveEofs = 0;

  // The number of the attempt about to be made, counted the same way the
  // delays back off, so the number shown next to a countdown always matches
  // the delay being waited out.
  get attempt() {
    return this.#failures + Math.max(0, this.#consecutiveEofs - 1) + 1;
  }

  // A batch arrived. A working stream ends the failure streak. The clean
  // endings are kept, since they back off servers that close every stream.
  streamWorked() {
    this.#failures = 0;
  }

  // The session was replaced by a new one, which is connected to at once.
  sessionReset() {
    this.#failures = 0;
  }

  // The stream ended cleanly. Returns the delay before the next attempt.
  ended() {
    this.#failures = 0;
    this.#consecutiveEofs += 1;
    return Math.min(MAX_DELAY, STEP * Math.max(0, this.#consecutiveEofs - 1));
  }

  // The attempt failed. Call `delay` for the wait before the next one.
  failed() {
    this.#consecutiveEofs = 0;
    this.#failures += 1;
  }

  get delay() {
    return Math.min(MAX_DELAY, STEP * this.#failures);
  }
}
