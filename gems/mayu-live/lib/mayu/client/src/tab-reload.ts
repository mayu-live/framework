const CHANNEL_NAME = "mayu:browser:v1";

// Lives for the document, independently of session reconnects or invalidation.
// One channel instance both sends and receives, so broadcasts exclude this tab.
export default class TabReloader {
  #channel: BroadcastChannel | null = null;
  #started = false;
  #reloadRequested = false;
  #reload: () => void;

  constructor(reload = () => window.location.reload()) {
    this.#reload = reload;
  }

  start() {
    if (this.#started) return;
    this.#started = true;
    this.#open();
    window.addEventListener("pagehide", this.#onPageHide);
    window.addEventListener("pageshow", this.#onPageShow);
  }

  reloadOtherTabs() {
    try {
      this.#channel?.postMessage({ type: "reload" });
    } catch {
      // An unavailable/closed channel must not interrupt other browser actions.
    }
  }

  dispose() {
    this.#started = false;
    window.removeEventListener("pagehide", this.#onPageHide);
    window.removeEventListener("pageshow", this.#onPageShow);
    this.#close();
  }

  #onMessage = (event: MessageEvent<unknown>) => {
    const data = event.data;
    if (
      !data ||
      typeof data !== "object" ||
      !("type" in data) ||
      data.type !== "reload" ||
      this.#reloadRequested
    )
      return;
    this.#reloadRequested = true;
    this.#reload();
  };

  #onPageHide = () => this.#close();

  #onPageShow = () => {
    this.#reloadRequested = false;
    this.#open();
  };

  #open() {
    if (this.#channel || typeof BroadcastChannel === "undefined") return;
    try {
      this.#channel = new BroadcastChannel(CHANNEL_NAME);
      this.#channel.addEventListener("message", this.#onMessage);
    } catch {
      this.#close();
    }
  }

  #close() {
    this.#channel?.removeEventListener("message", this.#onMessage);
    this.#channel?.close();
    this.#channel = null;
  }
}
