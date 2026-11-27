import html from "./mayu-connection-dialog.html";
import { part, shadowTemplate } from "./shadow";

const stamp = shadowTemplate(html);

const MESSAGES: Record<string, [title: string, text: string]> = {
  disconnected: ["Disconnected", "Trying to reconnect…"],
  transferring: ["Transferring", "Trying to restore connection…"],
};

// The dialog that covers the page while it has no connection, with the
// number of the reconnect attempt and a countdown to the next one.
export default class MayuConnectionDialog extends HTMLElement {
  #root = stamp(this);
  #dialog = part<HTMLDialogElement>(this.#root, "dialog");
  #attemptText = part<HTMLParagraphElement>(this.#root, "attempt");
  #countdown = part<HTMLDivElement>(this.#root, "countdown");
  #seconds = part<HTMLSpanElement>(this.#root, "seconds");

  #status: string | null = null;
  #attempt: string | null = null;
  #retryAt: number | null = null;
  // The deadline the countdown arc is running towards.
  #arcRetryAt: number | null = null;
  #secondsTimer?: number;
  #closeTimer?: number;

  constructor() {
    super();

    // The dialog stays until the connection is back.
    this.#dialog.addEventListener("cancel", (event) => event.preventDefault());
  }

  // The dialog is shown for "disconnected" and "transferring".
  set status(status: string | null) {
    this.#status = status;
    this.#renderDialog();
  }

  // `attempt` is the number of the reconnect attempt, or null when there is
  // none. `retryAt` is when the next one starts, in epoch milliseconds, or
  // null while one is running.
  setReconnect(attempt: string | null, retryAt: number | null) {
    this.#attempt = attempt;
    this.#retryAt = retryAt;
    this.#renderReconnect();
  }

  connectedCallback() {
    this.#renderDialog();
    this.#renderReconnect();
  }

  disconnectedCallback() {
    window.clearInterval(this.#secondsTimer);
    window.clearTimeout(this.#closeTimer);
    // Leaving the document closes a modal dialog. Start over from closed, so
    // that it opens again if the element comes back.
    this.#dialog.classList.remove("is-visible");
    this.#dialog.close();
    this.#arcRetryAt = null;
  }

  #renderDialog() {
    // A dialog can only be opened while it is in the document.
    if (!this.isConnected) return;

    const message = this.#status ? MESSAGES[this.#status] : undefined;
    if (!message) {
      this.#hide();
      return;
    }

    part(this.#root, "title").textContent = message[0];
    part(this.#root, "text").textContent = message[1];
    this.#show();
  }

  #show() {
    const dialog = this.#dialog;
    window.clearTimeout(this.#closeTimer);

    if (dialog.classList.contains("is-visible")) return;
    if (!dialog.open) dialog.showModal();

    // Force the scale(0) state to be painted before transitioning to scale(1).
    void dialog.offsetWidth;
    dialog.classList.add("is-visible");
  }

  #hide() {
    const dialog = this.#dialog;
    if (!dialog.open || !dialog.classList.contains("is-visible")) return;

    // Close once the transition out has run.
    dialog.classList.remove("is-visible");
    this.#closeTimer = window.setTimeout(() => {
      if (!dialog.classList.contains("is-visible")) dialog.close();
    }, 200);
  }

  #renderReconnect() {
    const text = this.#attemptText;
    const countdown = this.#countdown;
    const seconds = this.#seconds;
    const attempt = this.#attempt;
    const retryAt = this.#retryAt;

    window.clearInterval(this.#secondsTimer);
    text.hidden = countdown.hidden = !attempt;

    if (!attempt) {
      countdown.classList.remove("is-connecting", "is-waiting");
      this.#arcRetryAt = null;
      return;
    }

    if (!retryAt) {
      text.textContent = `Attempt ${attempt} · connecting…`;
      seconds.textContent = "";
      countdown.classList.remove("is-waiting");
      countdown.classList.add("is-connecting");
      this.#arcRetryAt = null;
      return;
    }

    text.textContent = `Attempt ${attempt} failed`;
    const renderSeconds = () => {
      const remaining = Math.max(0, Math.ceil((retryAt - Date.now()) / 1000));
      seconds.textContent = `${remaining}s`;
    };
    renderSeconds();
    if (this.isConnected) {
      this.#secondsTimer = window.setInterval(renderSeconds, 250);
    }

    // Only restart the arc for a new deadline.
    if (this.#arcRetryAt === retryAt) return;
    this.#arcRetryAt = retryAt;

    countdown.classList.remove("is-connecting", "is-waiting");
    countdown.style.setProperty(
      "--retry-duration",
      `${Math.max(0, retryAt - Date.now())}ms`,
    );
    // Force the class removal to be applied so the animation restarts.
    void countdown.getBoundingClientRect();
    countdown.classList.add("is-waiting");
  }
}

customElements.define("mayu-connection-dialog", MayuConnectionDialog);
