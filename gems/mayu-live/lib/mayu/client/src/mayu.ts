import serializeEvent from "./serializeEvent.js";
import { NAVIGATION_PROGRESS_DELAY, PING_INTERVAL } from "./constants";
import { updateNavigationProgress } from "./ping";
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

type NavigationLike = EventTarget & {
  navigate(url: string, options?: { history?: "push" | "replace" }): unknown;
};

type NavigateEventLike = Event & {
  canIntercept: boolean;
  destination: { url: string };
  downloadRequest: unknown | null;
  formData: FormData | null;
  hashChange: boolean;
  navigationType: string;
  signal: AbortSignal;
  intercept(options: { handler: () => Promise<void> }): void;
};

type PendingNavigation = {
  promise: Promise<void>;
  resolve: () => void;
  reject: (error: Error) => void;
  showTimer: ReturnType<typeof setTimeout> | null;
  shown: boolean;
  signal: AbortSignal;
  abortListener: () => void;
};

function browserNavigation(): NavigationLike | undefined {
  return (globalThis as typeof globalThis & { navigation?: NavigationLike })
    .navigation;
}

export default class Mayu {
  #writer: WritableStreamDefaultWriter<ClientEvent> | null;
  #pingScheduler: PingScheduler | null;
  #navigationListener: (event: Event) => void;
  #visibilityListener: () => void;
  #navigationSequence = 0;
  #pendingNavigations = new Map<string, PendingNavigation>();
  #activeNavigationId: string | null = null;

  constructor({ autoPing = true }: MayuOptions = {}) {
    this.#writer = null;

    this.#navigationListener = (event) => {
      this.#handleNavigation(event as NavigateEventLike);
    };
    browserNavigation()?.addEventListener("navigate", this.#navigationListener);

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
    browserNavigation()?.removeEventListener(
      "navigate",
      this.#navigationListener,
    );
    document.removeEventListener("visibilitychange", this.#visibilityListener);
    this.#pingScheduler?.stop();
    this.#pingScheduler = null;
    this.#rejectPendingNavigations(new Error("Mayu was disposed"));
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
    this.#rejectPendingNavigations(
      new Error("Navigation callback transport unavailable"),
    );
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
      if (this.#writer === writer) this.clearWriter();
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
    const navigation = browserNavigation();
    if (navigation) {
      navigation.navigate(href, { history: pushState ? "push" : "replace" });
      return;
    }

    window.location.assign(href);
  }

  completeNavigation(id: string) {
    this.#settleNavigation(id);
  }

  failNavigation(id: string) {
    this.#settleNavigation(id, new Error("Navigation failed"));
  }

  #handleNavigation(event: NavigateEventLike) {
    if (
      !event.canIntercept ||
      event.hashChange ||
      event.downloadRequest !== null ||
      event.formData !== null ||
      event.navigationType === "reload" ||
      !this.#writer
    ) {
      return;
    }

    const url = new URL(event.destination.url);
    if (url.origin !== location.origin) return;

    const id = `${++this.#navigationSequence}`;
    const pending = this.#beginNavigation(id, event.signal);

    event.intercept({
      handler: async () => {
        const wrote = await this.#sendNavigation(id, url.pathname + url.search);
        if (!wrote) this.failNavigation(id);
        await pending.promise;
      },
    });
  }

  #beginNavigation(id: string, signal: AbortSignal) {
    this.#rejectPendingNavigations(new Error("Navigation superseded"));

    let resolve!: () => void;
    let reject!: (error: Error) => void;
    const pending: PendingNavigation = {
      promise: new Promise<void>((resolvePromise, rejectPromise) => {
        resolve = resolvePromise;
        reject = rejectPromise;
      }),
      resolve,
      reject,
      showTimer: null,
      shown: false,
      signal,
      abortListener: () =>
        this.#settleNavigation(id, new Error("Navigation aborted")),
    };

    this.#pendingNavigations.set(id, pending);
    this.#activeNavigationId = id;
    signal.addEventListener("abort", pending.abortListener, { once: true });
    pending.showTimer = setTimeout(() => {
      if (this.#pendingNavigations.get(id) !== pending) return;

      pending.shown = true;
      updateNavigationProgress("pending");
    }, NAVIGATION_PROGRESS_DELAY);
    return pending;
  }

  #settleNavigation(id: string, error?: Error) {
    const pending = this.#pendingNavigations.get(id);
    if (!pending) return;

    this.#pendingNavigations.delete(id);
    if (pending.showTimer !== null) clearTimeout(pending.showTimer);
    pending.signal.removeEventListener("abort", pending.abortListener);

    if (this.#activeNavigationId === id) {
      this.#activeNavigationId = null;
      updateNavigationProgress(pending.shown && !error ? "complete" : null);
    }

    if (error) {
      pending.reject(error);
    } else {
      pending.resolve();
    }
  }

  #rejectPendingNavigations(error: Error) {
    for (const id of this.#pendingNavigations.keys()) {
      this.#settleNavigation(id, error);
    }
  }

  #sendNavigation(id: string, href: string) {
    console.warn("navigate", href);
    return this.#write(["Navigate", id, href, performance.now()]);
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
