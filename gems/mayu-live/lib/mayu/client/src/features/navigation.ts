import type Outbox from "../connection/outbox";
import type { CommandHandlers } from "../protocol/commands";
import { NAVIGATION_PROGRESS_DELAY } from "../protocol/constants";
import { updateNavigationProgress } from "../ui/status";

type NavigationLike = EventTarget & {
  transition?: { finished: Promise<unknown> } | null;
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
  sourceElement?: Element | null;
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
  documentHref?: string;
};

function browserNavigation(): NavigationLike | undefined {
  return (globalThis as typeof globalThis & { navigation?: NavigationLike })
    .navigation;
}

// Client-side routing. Same-origin navigations are intercepted with the
// Navigation API and sent to the server, and stay pending until the server
// has streamed the new page. Browsers without the Navigation API do
// ordinary document navigations.
export default class Navigation {
  #outbox: Outbox;
  #listener: (event: Event) => void;
  #sequence = 0;
  #pending = new Map<string, PendingNavigation>();
  #activeId: string | null = null;
  #documentNavigationHref: string | null = null;

  readonly handlers: CommandHandlers<
    "NavigationComplete" | "NavigationFailed" | "DocumentNavigation"
  > = {
    NavigationComplete: (id) => this.#settle(id),
    NavigationFailed: (id) => this.#settle(id, new Error("Navigation failed")),
    DocumentNavigation: (id, href) => {
      const pending = this.#pending.get(id);
      if (!pending) return;
      pending.documentHref = href;
      this.#settle(id);
    },
  };

  constructor(outbox: Outbox) {
    this.#outbox = outbox;

    this.#listener = (event) => {
      this.#handleNavigation(event as NavigateEventLike);
    };
    browserNavigation()?.addEventListener("navigate", this.#listener);

    outbox.onDisconnect(() => {
      this.#rejectPending(
        new Error("Navigation callback transport unavailable"),
      );
    });
  }

  dispose() {
    browserNavigation()?.removeEventListener("navigate", this.#listener);
    this.#rejectPending(new Error("Mayu was disposed"));
  }

  navigate(href: string, pushState: boolean = true, document: boolean = false) {
    if (document) {
      const target = new URL(href, location.href);
      this.#documentNavigationHref = target.href;
      if (
        target.origin === location.origin &&
        target.pathname === location.pathname &&
        target.search === location.search
      ) {
        // A fragment on the current resource makes assign/replace stay in
        // this document. Give this entry a temporary URL first, then replace
        // it with an HTTP navigation. Reload would also replace the document
        // associated with earlier live-navigation entries, breaking Back.
        const temporary = new URL(target);
        temporary.searchParams.append("__mayu_document_navigation", "");
        if (pushState) history.pushState(history.state, "", temporary.href);
        else history.replaceState(history.state, "", temporary.href);
        location.replace(target.href);
      } else if (pushState) location.assign(href);
      else location.replace(href);
      return;
    }
    const navigation = browserNavigation();
    if (navigation) {
      navigation.navigate(href, {
        history: pushState ? "push" : "replace",
        info: BROWSER_ACTION_NAVIGATION,
      });
      return;
    }

    if (pushState) location.assign(href);
    else location.replace(href);
  }

  #handleNavigation(event: NavigateEventLike) {
    if (event.destination.url === this.#documentNavigationHref) {
      this.#documentNavigationHref = null;
      return;
    }
    if (
      documentNavigationSource(event.sourceElement) ||
      !event.canIntercept ||
      event.hashChange ||
      event.downloadRequest !== null ||
      event.formData !== null ||
      event.navigationType === "reload" ||
      !this.#outbox.connected
    ) {
      return;
    }

    const url = new URL(event.destination.url);
    if (url.origin !== location.origin) return;

    const id = `${++this.#sequence}`;
    const pending = this.#begin(id, event.signal);

    // A server-initiated navigation that only changes the query string
    // updates the current page, e.g. a search field that syncs to ?q=. The
    // browser would otherwise move focus to <body> and reset the scroll
    // position once the navigation finishes.
    const inPlace =
      event.info === BROWSER_ACTION_NAVIGATION &&
      url.pathname === location.pathname;

    event.intercept({
      handler: async () => {
        const wrote = await this.#outbox.send([
          "Navigate",
          id,
          url.pathname + url.search,
        ]);
        if (!wrote) this.#settle(id, new Error("Navigation failed"));
        await pending.promise;
        if (pending.documentHref !== undefined) {
          const target = new URL(pending.documentHref, url);
          target.hash = url.hash;
          // Finish the intercepted history entry before replacing it with a
          // real HTTP request. Waiting here would deadlock the transition.
          const finished =
            browserNavigation()?.transition?.finished ?? Promise.resolve();
          void finished.then(
            () => {
              if (!event.signal.aborted && id === `${this.#sequence}`) {
                this.navigate(target.href, false, true);
              }
            },
            () => undefined,
          );
        }
      },
      ...(inPlace ? ({ focusReset: "manual", scroll: "manual" } as const) : {}),
    });
  }

  #begin(id: string, signal: AbortSignal) {
    this.#rejectPending(new Error("Navigation superseded"));

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
      abortListener: () => this.#settle(id, new Error("Navigation aborted")),
    };

    this.#pending.set(id, pending);
    this.#activeId = id;
    signal.addEventListener("abort", pending.abortListener, { once: true });
    pending.showTimer = setTimeout(() => {
      if (this.#pending.get(id) !== pending) return;

      pending.shown = true;
      updateNavigationProgress("pending");
    }, NAVIGATION_PROGRESS_DELAY);
    return pending;
  }

  #settle(id: string, error?: Error) {
    const pending = this.#pending.get(id);
    if (!pending) return;

    this.#pending.delete(id);
    if (pending.showTimer !== null) clearTimeout(pending.showTimer);
    pending.signal.removeEventListener("abort", pending.abortListener);

    if (this.#activeId === id) {
      this.#activeId = null;
      updateNavigationProgress(pending.shown && !error ? "complete" : null);
    }

    if (error) {
      pending.reject(error);
    } else {
      pending.resolve();
    }
  }

  #rejectPending(error: Error) {
    for (const id of this.#pending.keys()) {
      this.#settle(id, error);
    }
  }
}

// sourceElement can be a link, a form, or a form-associated submit button.
function documentNavigationSource(source?: Element | null): boolean {
  if (!source) return false;
  const submitter = source.closest("button, input");
  const form =
    submitter instanceof HTMLButtonElement ||
    submitter instanceof HTMLInputElement
      ? submitter.form
      : source.closest("form");
  const mode =
    submitter?.getAttribute("data-mayu-navigation") ??
    form?.getAttribute("data-mayu-navigation") ??
    source.closest("a")?.getAttribute("data-mayu-navigation");
  return mode === "document";
}
