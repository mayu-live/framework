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
  #ticker: PingTicker | null;
  #popstateListener: () => void;
  #visibilityListener: () => void;

  constructor({ autoPing = true }: MayuOptions = {}) {
    this.#writer = null;

    this.#popstateListener = () => {
      this.navigate(location.pathname + location.search, false);
    };
    window.addEventListener("popstate", this.#popstateListener);

    // A tab coming back to the foreground pings right away, so a session
    // that survived the background gets its status updated immediately.
    this.#visibilityListener = () => {
      if (document.visibilityState === "visible") this.ping();
    };
    document.addEventListener("visibilitychange", this.#visibilityListener);

    this.#ticker = null;
    if (autoPing) {
      this.#ticker = new PingTicker(PING_INTERVAL, () => this.ping());
      this.#ticker.start();
    }
  }

  dispose() {
    window.removeEventListener("popstate", this.#popstateListener);
    document.removeEventListener("visibilitychange", this.#visibilityListener);
    this.#ticker?.stop();
    this.#ticker = null;
  }

  setWriter(writer: WritableStreamDefaultWriter<ClientEvent>) {
    this.#writer = writer;
  }

  clearWriter() {
    this.#writer = null;
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

// Pings keep the session alive on the server. Browsers throttle a hidden
// tab's timers, Chrome down to once a minute, which is longer than the
// server's session timeout. Timers in a dedicated worker keep their cadence,
// so the ticker runs there when it can and falls back to a page timer.
export class PingTicker {
  #interval: number;
  #tick: () => void;
  #worker: Worker | null = null;
  #timer: ReturnType<typeof setInterval> | null = null;

  constructor(interval: number, tick: () => void) {
    this.#interval = interval;
    this.#tick = tick;
  }

  start() {
    const ticker = createTickerWorker(this.#interval);

    if (ticker) {
      this.#worker = ticker.worker;
      this.#worker.onmessage = () => {
        // The script has loaded once the first tick arrives.
        if (ticker.url) URL.revokeObjectURL(ticker.url);
        ticker.url = null;
        this.#tick();
      };
    } else {
      this.#timer = setInterval(() => this.#tick(), this.#interval);
    }
  }

  stop() {
    this.#worker?.terminate();
    this.#worker = null;
    if (this.#timer !== null) clearInterval(this.#timer);
    this.#timer = null;
  }
}

function createTickerWorker(
  interval: number,
): { worker: Worker; url: string | null } | null {
  if (typeof Worker === "undefined") return null;
  if (typeof URL.createObjectURL !== "function") return null;

  try {
    const source = `setInterval(() => postMessage(0), ${interval});`;
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
