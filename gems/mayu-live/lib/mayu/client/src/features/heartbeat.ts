import type Outbox from "../connection/outbox";
import type { CommandHandlers } from "../protocol/commands";
import { PING_INTERVAL } from "../protocol/constants";
import { updatePing } from "../ui/status";

type HeartbeatOptions = {
  autoPing?: boolean;
};

// Keeps the session alive with pings, shows the round-trip time the server
// answers with, and tells the server whether the tab is visible.
export default class Heartbeat {
  #outbox: Outbox;
  #scheduler: PingScheduler | null = null;
  #visibilityListener: () => void;

  readonly handlers: CommandHandlers<"Pong"> = {
    Pong: (timestamp) => updatePing(performance.now() - timestamp),
  };

  constructor(outbox: Outbox, { autoPing = true }: HeartbeatOptions = {}) {
    this.#outbox = outbox;

    // The server slows its updates down while nobody is looking, and a tab
    // back in the foreground pings right away so its status updates.
    this.#visibilityListener = () => {
      this.#sendVisibility();
      if (document.visibilityState === "visible") this.ping();
    };
    document.addEventListener("visibilitychange", this.#visibilityListener);

    if (autoPing) {
      this.#scheduler = new PingScheduler(PING_INTERVAL, () => this.ping());
    }

    outbox.onConnect(() => {
      this.#scheduler?.reset();
      // A session that connects from a hidden tab starts out slowed down.
      if (document.visibilityState === "hidden") this.#sendVisibility();
    });
    outbox.onSend(() => this.#scheduler?.reset());
    outbox.onDisconnect(() => this.#scheduler?.cancel());
  }

  dispose() {
    document.removeEventListener("visibilitychange", this.#visibilityListener);
    this.#scheduler?.stop();
    this.#scheduler = null;
  }

  ping() {
    void this.#outbox.send(["Ping"]);
  }

  #sendVisibility() {
    const hidden = document.visibilityState === "hidden";
    void this.#outbox.send(["Visibility", hidden]);
  }
}

// Pings keep an idle session alive. Every outbound event refreshes the same
// server-side liveness timestamp, so the next ping is delayed until there has
// been no traffic for the interval. A dedicated worker avoids hidden-tab timer
// throttling and only holds one timeout at a time.
class PingScheduler {
  #interval: number;
  #tick: () => void;
  #worker: Worker | null = null;
  #workerUnavailable = false;
  #timer: ReturnType<typeof setTimeout> | null = null;

  constructor(interval: number, tick: () => void) {
    this.#interval = interval;
    this.#tick = tick;
  }

  reset() {
    if (!this.#worker && !this.#workerUnavailable) {
      const ticker = createPingWorker();
      if (ticker) {
        this.#worker = ticker.worker;
        this.#worker.onmessage = () => this.#tick();
        if (ticker.url) URL.revokeObjectURL(ticker.url);
      } else {
        this.#workerUnavailable = true;
      }
    }

    if (this.#worker) {
      this.#worker.postMessage(this.#interval);
      return;
    }

    if (this.#timer !== null) clearTimeout(this.#timer);
    this.#timer = setTimeout(() => this.#tick(), this.#interval);
  }

  cancel() {
    this.#worker?.postMessage(null);
    if (this.#timer !== null) clearTimeout(this.#timer);
    this.#timer = null;
  }

  stop() {
    this.cancel();
    this.#worker?.terminate();
    this.#worker = null;
  }
}

function createPingWorker(): { worker: Worker; url: string | null } | null {
  if (typeof Worker === "undefined") return null;
  if (typeof URL.createObjectURL !== "function") return null;

  try {
    const source = `let timer; onmessage = ({data}) => { clearTimeout(timer); if (data) timer = setTimeout(() => postMessage(0), data); };`;
    const url = URL.createObjectURL(
      new Blob([source], { type: "text/javascript" }),
    );
    return { worker: new Worker(url), url };
  } catch {
    // A content security policy may forbid blob workers.
    return null;
  }
}
