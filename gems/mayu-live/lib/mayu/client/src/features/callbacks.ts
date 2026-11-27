import type Outbox from "../connection/outbox";
import type { CommandHandlers } from "../protocol/commands";
import serializeEvent from "./serialize-event";
import { attachSettlement } from "./settled";
import Throttle from "./throttle";

// Checked against client/protocol.json, as is the server's list.
export const CONTINUOUS_EVENTS = new Set([
  "input",
  "mousemove",
  "pointermove",
  "touchmove",
  "wheel",
  "scroll",
  "drag",
  "dragover",
]);

type PendingCallback = {
  resolve: () => void;
  reject: (error: Error) => void;
};

// Sends the DOM events that reach a server-side handler, and settles them
// when the server reports that the handler has returned.
export default class Callbacks {
  #outbox: Outbox;
  #throttle = new Throttle();
  #sequence = 0;
  #pending = new Map<string, PendingCallback>();

  readonly handlers: CommandHandlers<"CallbackComplete" | "CallbackFailed"> = {
    CallbackComplete: (id) => this.#settle(id),
    CallbackFailed: (id) => this.#settle(id, new Error("Callback failed")),
  };

  constructor(outbox: Outbox) {
    this.#outbox = outbox;

    outbox.onDisconnect(() => {
      this.#throttle.clear();
      // Events are not replayed after a reconnect, so these are never
      // answered.
      this.#rejectPending(new Error("Callback transport unavailable"));
    });
  }

  dispose() {
    this.#throttle.clear();
    this.#rejectPending(new Error("Mayu was disposed"));
  }

  // Called for every event a server-side listener is registered for.
  dispatch(event: Event, listenerId: string) {
    // Some default actions are pure browser UI, such as showing a popover or
    // closing a dialog, so they run alongside the callback.
    if (!keepsDefaultAction(event)) event.preventDefault();

    const serializedEvent = serializeEvent(event);

    // Continuous events are throttled and merged, so they are not tracked.
    if (CONTINUOUS_EVENTS.has(event.type)) {
      this.#throttle.call(`${event.type}:${listenerId}`, () => {
        void this.#outbox.send(["Callback", listenerId, serializedEvent]);
      });
      return;
    }

    // Send held back continuous events first, so that an input value
    // reaches the server before the submit that follows it.
    this.#throttle.flush();

    // The server answers with CallbackComplete or CallbackFailed once the
    // handler has returned, after the updates it made.
    const settleId = `${++this.#sequence}`;
    const promise = new Promise<void>((resolve, reject) => {
      this.#pending.set(settleId, { resolve, reject });
    });
    attachSettlement(event, promise);

    void this.#outbox
      .send(["Callback", listenerId, serializedEvent, settleId])
      .then((wrote) => {
        if (!wrote) this.#settle(settleId, new Error("Callback not sent"));
      });
  }

  #settle(id: string, error?: Error) {
    const pending = this.#pending.get(id);
    if (!pending) return;

    this.#pending.delete(id);

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
