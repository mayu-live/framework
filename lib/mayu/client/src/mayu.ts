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
  #pingTimer: number | null;
  #popstateListener: () => void;

  constructor({ autoPing = true }: MayuOptions = {}) {
    this.#writer = null;

    this.#popstateListener = () => {
      this.navigate(location.pathname + location.search, false);
    };
    window.addEventListener("popstate", this.#popstateListener);

    this.#pingTimer = null;
    if (autoPing) this.#scheduleNextPing(100);
  }

  dispose() {
    window.removeEventListener("popstate", this.#popstateListener);
    if (this.#pingTimer !== null) clearTimeout(this.#pingTimer);
    this.#pingTimer = null;
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
    event.preventDefault();

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
    this.#scheduleNextPing(PING_INTERVAL);

    void this.#write(["Ping", performance.now()]);
  }

  #scheduleNextPing(delay: number) {
    if (this.#pingTimer !== null) clearTimeout(this.#pingTimer);
    this.#pingTimer = setTimeout(() => this.ping(), delay);
  }
}
