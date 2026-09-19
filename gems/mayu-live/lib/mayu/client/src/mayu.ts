import serializeEvent from "./serializeEvent.js";
import { PING_INTERVAL } from "./constants";
import throttle from "./throttle";
import type { ClientEvent } from "./protocol";

const CONTINUOUS_EVENTS = new Set([
  "input",
  "mousemove",
  "pointermove",
  "touchmove",
  "wheel",
]);

type MayuOptions = {
  autoPing?: boolean;
};

export default class Mayu {
  #writer: WritableStreamDefaultWriter<ClientEvent> | null;
  #pingScheduler: PingScheduler | null;
  #popstateListener: () => void;
  #visibilityListener: () => void;

  constructor({ autoPing = true }: MayuOptions = {}) {
    this.#writer = null;

    this.#popstateListener = () => {
      this.navigate(location.pathname + location.search, false);
    };
    window.addEventListener("popstate", this.#popstateListener);

    // The server slows its updates down while nobody is looking, and a tab
    // back in the foreground pings right away so its status updates.
    this.#visibilityListener = () => {
      this.#sendVisibility();
      if (document.visibilityState === "visible") this.ping();
    };
    document.addEventListener("visibilitychange", this.#visibilityListener);

    this.#pingScheduler = null;
    if (autoPing) {
      this.#pingScheduler = new PingScheduler(PING_INTERVAL, () => this.ping());
    }
  }

  dispose() {
    window.removeEventListener("popstate", this.#popstateListener);
    document.removeEventListener("visibilitychange", this.#visibilityListener);
    this.#pingScheduler?.stop();
    this.#pingScheduler = null;
  }

  setWriter(writer: WritableStreamDefaultWriter<ClientEvent>) {
    this.#writer = writer;
    this.#pingScheduler?.reset();
    // A session that connects from a hidden tab starts out slowed down.
    if (document.visibilityState === "hidden") this.#sendVisibility();
  }

  #sendVisibility() {
    const hidden = document.visibilityState === "hidden";
    void this.#write(["Visibility", hidden, performance.now()]);
  }

  clearWriter() {
    this.#writer = null;
    this.#pingScheduler?.cancel();
  }

  async #write(message: ClientEvent) {
    const eventName = message[0].toLowerCase();
    const writer = this.#writer;
    if (!writer) {
      console.warn(`Dropping ${eventName}: callback transport unavailable`);
      return false;
    }

    try {
      await writer.write(message);
      this.#pingScheduler?.reset();
      return true;
    } catch (error) {
      if (this.#writer === writer) this.#writer = null;
      console.error(`Dropping ${eventName}: callback write failed`, error);
      return false;
    }
  }

  callback(event: Event, id: string) {
    // The default action of a popover invoker button is to show or hide its
    // popover. That is pure browser UI, so let it run alongside the callback.
    if (!isPopoverInvokerClick(event)) event.preventDefault();

    const serializedEvent = serializeEvent(event);

    const write = () => {
      void this.#write(["Callback", id, serializedEvent, performance.now()]);
    };

    if (CONTINUOUS_EVENTS.has(event.type)) {
      throttle(event.currentTarget!, `${event.type}:${id}`, write);
    } else {
      write();
    }
  }

  navigate(href: string, pushState: boolean = true) {
    console.warn("navigate", href);

    void this.#write(["Navigate", href, pushState, performance.now()]);
  }

  ping() {
    void this.#write(["Ping", performance.now()]);
  }
}

// Pings keep an idle session alive. Every outbound event refreshes the same
// server-side liveness timestamp, so the next ping is delayed until there has
// been no traffic for the interval. A dedicated worker avoids hidden-tab timer
// throttling and only holds one timeout at a time.
export class PingScheduler {
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

function isPopoverInvokerClick(event: Event) {
  return (
    event.type === "click" &&
    event.currentTarget instanceof HTMLButtonElement &&
    event.currentTarget.hasAttribute("popovertarget")
  );
}
