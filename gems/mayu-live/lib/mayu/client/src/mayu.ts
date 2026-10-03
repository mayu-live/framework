import serializeEvent from "./serializeEvent.js";
import { NAVIGATION_PROGRESS_DELAY, PING_INTERVAL } from "./constants";
import { updateNavigationProgress } from "./ping";
import Throttle from "./throttle";
import { attachSettlement } from "./settled";
import type { ClientEvent, CommandApplyTelemetry } from "./protocol";

const CONTINUOUS_EVENTS = new Set([
  "input",
  "mousemove",
  "pointermove",
  "touchmove",
  "wheel",
  "scroll",
  "drag",
  "dragover",
]);

type MayuOptions = {
  autoPing?: boolean;
};

type NavigationLike = EventTarget & {
  navigate(
    url: string,
    options?: { history?: "push" | "replace"; info?: unknown },
  ): unknown;
};

type NavigateEventLike = Event & {
  canIntercept: boolean;
  destination: { url: string };
  downloadRequest: unknown | null;
  formData: FormData | null;
  hashChange: boolean;
  info?: unknown;
  navigationType: string;
  signal: AbortSignal;
  intercept(options: {
    handler: () => Promise<void>;
    focusReset?: "after-transition" | "manual";
    scroll?: "after-transition" | "manual";
  }): void;
};

// Marks navigations started by `browser.navigate` on the server.
const BROWSER_ACTION_NAVIGATION = "mayu:browser-action";

type PendingNavigation = {
  promise: Promise<void>;
  resolve: () => void;
  reject: (error: Error) => void;
  showTimer: ReturnType<typeof setTimeout> | null;
  shown: boolean;
  signal: AbortSignal;
  abortListener: () => void;
};

type OutboundEvent =
  | [
      name: "Callback",
      listenerId: string,
      event: Record<string, unknown>,
      ping: number,
    ]
  | [
      name: "Callback",
      listenerId: string,
      event: Record<string, unknown>,
      ping: number,
      settleId: string,
    ]
  | [name: "Navigate", id: string, href: string, ping: number]
  | [name: "Ping", ping: number]
  | [name: "Visibility", hidden: boolean, ping: number]
  | [name: "Inspect", id: string, query: Record<string, unknown>, ping: number];

type PendingInspect = {
  resolve: (result: unknown) => void;
  reject: (error: Error) => void;
  timer: ReturnType<typeof setTimeout>;
};

// Events are dropped rather than replayed across disconnects, so an inspect
// request may never be answered.
const INSPECT_TIMEOUT = 5000;

type PendingCallback = {
  resolve: () => void;
  reject: (error: Error) => void;
};

function browserNavigation(): NavigationLike | undefined {
  return (globalThis as typeof globalThis & { navigation?: NavigationLike })
    .navigation;
}

export default class Mayu {
  #writer: WritableStreamDefaultWriter<ClientEvent> | null;
  #pingScheduler: PingScheduler | null;
  #throttle = new Throttle();
  #navigationListener: (event: Event) => void;
  #visibilityListener: () => void;
  #navigationSequence = 0;
  #pendingNavigations = new Map<string, PendingNavigation>();
  #activeNavigationId: string | null = null;
  #inspectSequence = 0;
  #pendingInspects = new Map<string, PendingInspect>();
  #callbackSequence = 0;
  #pendingCallbacks = new Map<string, PendingCallback>();
  #commandApplyTelemetry: CommandApplyTelemetry = {
    batches: 0,
    commands: 0,
    duration_ms: 0,
  };

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
    this.#throttle.clear();
    this.#pingScheduler?.stop();
    this.#pingScheduler = null;
    this.#rejectPendingNavigations(new Error("Mayu was disposed"));
    this.#rejectPendingCallbacks(new Error("Mayu was disposed"));
    for (const id of this.#pendingInspects.keys()) {
      this.#settleInspect(id, undefined, new Error("Mayu was disposed"));
    }
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
    this.#throttle.clear();
    this.#pingScheduler?.cancel();
    this.#rejectPendingNavigations(
      new Error("Navigation callback transport unavailable"),
    );
    // Events are not replayed after a reconnect, so these are never answered.
    this.#rejectPendingCallbacks(new Error("Callback transport unavailable"));
  }

  recordCommandApply(commands: number, durationMs: number) {
    this.#commandApplyTelemetry.batches += 1;
    this.#commandApplyTelemetry.commands += commands;
    this.#commandApplyTelemetry.duration_ms += durationMs;
  }

  async #write(message: OutboundEvent) {
    const eventName = message[0].toLowerCase();
    const writer = this.#writer;
    if (!writer) {
      console.warn(`Dropping ${eventName}: callback transport unavailable`);
      return false;
    }

    const telemetry = this.#takeCommandApplyTelemetry();
    const event: ClientEvent = telemetry ? [...message, telemetry] : message;

    try {
      await writer.write(event);
      this.#pingScheduler?.reset();
      return true;
    } catch (error) {
      if (telemetry) this.#restoreCommandApplyTelemetry(telemetry);
      if (this.#writer === writer) this.clearWriter();
      console.error(`Dropping ${eventName}: callback write failed`, error);
      return false;
    }
  }

  #takeCommandApplyTelemetry() {
    if (this.#commandApplyTelemetry.batches === 0) return undefined;

    const telemetry = this.#commandApplyTelemetry;
    this.#commandApplyTelemetry = { batches: 0, commands: 0, duration_ms: 0 };
    return telemetry;
  }

  #restoreCommandApplyTelemetry(telemetry: CommandApplyTelemetry) {
    this.#commandApplyTelemetry.batches += telemetry.batches;
    this.#commandApplyTelemetry.commands += telemetry.commands;
    this.#commandApplyTelemetry.duration_ms += telemetry.duration_ms;
  }

  callback(event: Event, id: string) {
    // Some default actions are pure browser UI, such as showing a popover or
    // closing a dialog, so they run alongside the callback.
    if (!keepsDefaultAction(event)) event.preventDefault();

    const serializedEvent = serializeEvent(event);

    // Continuous events are throttled and merged, so they are not tracked.
    if (CONTINUOUS_EVENTS.has(event.type)) {
      this.#throttle.call(`${event.type}:${id}`, () => {
        void this.#write(["Callback", id, serializedEvent, performance.now()]);
      });
      return;
    }

    // Send held back continuous events first, so that an input value
    // reaches the server before the submit that follows it.
    this.#throttle.flush();

    // The server answers with CallbackComplete or CallbackFailed once the
    // handler has returned, after the updates it made.
    const settleId = `${++this.#callbackSequence}`;
    const promise = new Promise<void>((resolve, reject) => {
      this.#pendingCallbacks.set(settleId, { resolve, reject });
    });
    attachSettlement(event, promise);

    void this.#write([
      "Callback",
      id,
      serializedEvent,
      performance.now(),
      settleId,
    ]).then((wrote) => {
      if (!wrote) {
        this.#settleCallback(settleId, new Error("Callback not sent"));
      }
    });
  }

  completeCallback(id: string) {
    this.#settleCallback(id);
  }

  failCallback(id: string) {
    this.#settleCallback(id, new Error("Callback failed"));
  }

  #settleCallback(id: string, error?: Error) {
    const pending = this.#pendingCallbacks.get(id);
    if (!pending) return;

    this.#pendingCallbacks.delete(id);

    if (error) {
      pending.reject(error);
    } else {
      pending.resolve();
    }
  }

  #rejectPendingCallbacks(error: Error) {
    for (const id of this.#pendingCallbacks.keys()) {
      this.#settleCallback(id, error);
    }
  }

  navigate(href: string, pushState: boolean = true) {
    const navigation = browserNavigation();
    if (navigation) {
      navigation.navigate(href, {
        history: pushState ? "push" : "replace",
        info: BROWSER_ACTION_NAVIGATION,
      });
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

    // A server-initiated navigation that only changes the query string
    // updates the current page, e.g. a search field that syncs to ?q=. The
    // browser would otherwise move focus to <body> and reset the scroll
    // position once the navigation finishes.
    const inPlace =
      event.info === BROWSER_ACTION_NAVIGATION &&
      url.pathname === location.pathname;

    event.intercept({
      handler: async () => {
        const wrote = await this.#sendNavigation(id, url.pathname + url.search);
        if (!wrote) this.failNavigation(id);
        await pending.promise;
      },
      ...(inPlace ? ({ focusReset: "manual", scroll: "manual" } as const) : {}),
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

  // Asks the server's devtools inspector a question. Resolves with its
  // answer, which is null when the server has no inspector.
  inspect(query: Record<string, unknown>): Promise<unknown> {
    const id = `${++this.#inspectSequence}`;
    const promise = new Promise<unknown>((resolve, reject) => {
      const timer = setTimeout(
        () =>
          this.#settleInspect(id, undefined, new Error("Inspect timed out")),
        INSPECT_TIMEOUT,
      );
      this.#pendingInspects.set(id, { resolve, reject, timer });
    });

    void this.#write(["Inspect", id, query, performance.now()]).then(
      (wrote) => {
        if (!wrote) {
          this.#settleInspect(id, undefined, new Error("Inspect not sent"));
        }
      },
    );

    return promise;
  }

  resolveInspect(id: string, result: unknown) {
    this.#settleInspect(id, result);
  }

  #settleInspect(id: string, result: unknown, error?: Error) {
    const pending = this.#pendingInspects.get(id);
    if (!pending) return;

    this.#pendingInspects.delete(id);
    clearTimeout(pending.timer);

    if (error) {
      pending.reject(error);
    } else {
      pending.resolve(result);
    }
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

// Clicks on popover and command invoker buttons (popovertarget, commandfor)
// show, hide or close their targets, and submitting a form with
// method="dialog" closes its dialog. None of them navigate.
function keepsDefaultAction(event: Event) {
  if (event.type === "click") {
    const button = event.currentTarget;
    return (
      button instanceof HTMLButtonElement &&
      (button.hasAttribute("popovertarget") ||
        button.hasAttribute("commandfor"))
    );
  }

  if (event.type === "submit") {
    return submitMethod(event) === "dialog";
  }

  return false;
}

function submitMethod(event: Event) {
  const form = event.target;
  if (!(form instanceof HTMLFormElement)) return null;

  const submitter = (event as SubmitEvent).submitter;
  const method =
    submitter?.getAttribute("formmethod") ?? form.getAttribute("method");

  return method?.toLowerCase() ?? null;
}
