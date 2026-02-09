import serializeEvent from "./serializeEvent.js";
import { PING_INTERVAL } from "./constants";
import throttle from "./throttle";

export default class Mayu {
  #writer: WritableStreamDefaultWriter<any> | null;
  #pingTimer: number;

  constructor() {
    this.#writer = null;

    window.addEventListener("popstate", () => {
      this.navigate(location.pathname + location.search, false);
    });

    this.#pingTimer = setTimeout(() => this.ping(), 100);
  }

  setWriter(writer: WritableStreamDefaultWriter<any>) {
    this.#writer = writer;
  }

  async #write(message: any) {
    try {
      await this.#writer?.write(message);
    } catch (_error) {
      console.error("Write error");
    }
  }

  callback(event: Event, id: string) {
    event.preventDefault();

    const serializedEvent = serializeEvent(event);

    throttle(event.currentTarget!, () => {
      this.#write({
        type: "callback",
        payload: { id, event: serializedEvent },
        ping: performance.now(),
      });
    });
  }

  navigate(href: string, pushState: boolean = true) {
    console.warn("navigate", href);

    this.#write({
      type: "navigate",
      payload: { href, pushState },
      ping: performance.now(),
    });
  }

  ping() {
    clearTimeout(this.#pingTimer);

    this.#pingTimer = setTimeout(() => this.ping(), PING_INTERVAL);

    this.#write({
      type: "ping",
      ping: performance.now(),
    });
  }
}
