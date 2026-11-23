import html from "./mayu-ping.html";

const template = document.createElement("template");
template.innerHTML = html;

class MayuPing extends HTMLElement {
  #div?: HTMLDivElement;
  #ping?: HTMLSpanElement;
  #disconnectDialog?: HTMLDialogElement;
  #disconnectTitle?: HTMLParagraphElement;
  #disconnectText?: HTMLParagraphElement;
  #reconnectStatus?: HTMLParagraphElement;
  #reconnectCountdown?: HTMLDivElement;
  #reconnectSeconds?: HTMLSpanElement;
  #reconnectTimer?: number;
  #renderedRetryAt?: number | null;
  #navigationProgress?: HTMLDivElement;
  #closeDialogTimer?: number;
  #navigationCompleteTimer?: number;
  #updatePosition = () => {
    const ping = this.#div;
    if (!ping) return;

    const viewport = window.visualViewport;
    const offsetLeft = viewport?.offsetLeft ?? 0;
    const offsetTop = viewport?.offsetTop ?? 0;
    const width = viewport?.width ?? window.innerWidth;
    const height = viewport?.height ?? window.innerHeight;

    ping.style.transform = `translate(${offsetLeft + width - ping.offsetWidth}px, ${offsetTop + height - ping.offsetHeight}px)`;
  };

  static observedAttributes = [
    "ping",
    "status",
    "navigation",
    "reconnect-attempt",
    "reconnect-at",
  ];

  connectedCallback() {
    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.replaceChildren(template.content.cloneNode(true));

    this.#div = this.shadowRoot!.querySelector(".mayu-ping") as HTMLDivElement;
    this.#ping = this.shadowRoot!.querySelector(".ping") as HTMLSpanElement;
    this.#disconnectDialog = this.shadowRoot!.querySelector(
      ".disconnect-dialog",
    ) as HTMLDialogElement;
    this.#disconnectTitle = this.shadowRoot!.querySelector(
      ".disconnect-title",
    ) as HTMLParagraphElement;
    this.#disconnectText = this.shadowRoot!.querySelector(
      ".disconnect-text",
    ) as HTMLParagraphElement;
    this.#reconnectStatus = this.shadowRoot!.querySelector(
      ".reconnect-status",
    ) as HTMLParagraphElement;
    this.#reconnectCountdown = this.shadowRoot!.querySelector(
      ".reconnect-countdown",
    ) as HTMLDivElement;
    this.#reconnectSeconds = this.shadowRoot!.querySelector(
      ".reconnect-seconds",
    ) as HTMLSpanElement;
    this.#navigationProgress = this.shadowRoot!.querySelector(
      ".navigation-progress",
    ) as HTMLDivElement;
    this.#updatePosition();
    window.addEventListener("scroll", this.#updatePosition, { passive: true });
    window.visualViewport?.addEventListener("resize", this.#updatePosition);
    window.visualViewport?.addEventListener("scroll", this.#updatePosition);
    this.#disconnectDialog?.addEventListener("cancel", (event) => {
      // Keep this modal non-cancelable while connection is unavailable.
      event.preventDefault();
    });

    const status = this.getAttribute("status");

    if (status) {
      this.attributeChangedCallback("status", "", status);
    }

    this.#renderedRetryAt = undefined;
    this.#updateReconnectStatus();

    const navigation = this.getAttribute("navigation");
    if (navigation) {
      this.attributeChangedCallback("navigation", "", navigation);
    }
  }

  disconnectedCallback() {
    window.removeEventListener("scroll", this.#updatePosition);
    window.visualViewport?.removeEventListener("resize", this.#updatePosition);
    window.visualViewport?.removeEventListener("scroll", this.#updatePosition);
    window.clearTimeout(this.#navigationCompleteTimer);
    window.clearInterval(this.#reconnectTimer);
  }

  attributeChangedCallback(name: string, oldValue: string, newValue: string) {
    switch (name) {
      case "ping":
        if (!this.#ping) return;
        this.#ping.textContent = newValue;
        this.#updatePosition();
        break;
      case "status":
        const classList = this.#div?.classList;
        if (oldValue && oldValue !== newValue) {
          classList?.remove(`status-${oldValue}`);
        }
        if (newValue) {
          classList?.add(`status-${newValue}`);
        }
        this.#updateConnectionDialog(newValue);
        break;
      case "navigation":
        this.#updateNavigationProgress(newValue);
        break;
      case "reconnect-attempt":
      case "reconnect-at":
        this.#updateReconnectStatus();
        break;
    }
  }

  #updateConnectionDialog(status: string) {
    const dialog = this.#disconnectDialog;
    const title = this.#disconnectTitle;
    const text = this.#disconnectText;
    if (!dialog || !title || !text) return;

    if (status === "disconnected") {
      title.textContent = "Disconnected";
      text.textContent = "Trying to reconnect…";
      this.#showConnectionDialog(dialog);
      return;
    }

    if (status === "transferring") {
      title.textContent = "Transferring";
      text.textContent = "Trying to restore connection…";
      this.#showConnectionDialog(dialog);
      return;
    }

    this.#hideConnectionDialog(dialog);
  }

  #updateReconnectStatus() {
    const status = this.#reconnectStatus;
    const countdown = this.#reconnectCountdown;
    const seconds = this.#reconnectSeconds;
    if (!status || !countdown || !seconds) return;

    const attempt = this.getAttribute("reconnect-attempt");
    const retryAtAttribute = this.getAttribute("reconnect-at");
    const retryAt = retryAtAttribute ? Number(retryAtAttribute) : null;

    window.clearInterval(this.#reconnectTimer);

    if (!attempt) {
      status.hidden = true;
      countdown.hidden = true;
      countdown.classList.remove("is-connecting", "is-waiting");
      this.#renderedRetryAt = undefined;
      return;
    }

    status.hidden = false;
    countdown.hidden = false;

    if (!retryAt) {
      status.textContent = `Attempt ${attempt} · connecting…`;
      seconds.textContent = "";
      countdown.classList.remove("is-waiting");
      countdown.classList.add("is-connecting");
      this.#renderedRetryAt = null;
      return;
    }

    status.textContent = `Attempt ${attempt} failed`;
    const renderSeconds = () => {
      const remaining = Math.max(0, Math.ceil((retryAt - Date.now()) / 1000));
      seconds.textContent = `${remaining}s`;
    };
    renderSeconds();
    this.#reconnectTimer = window.setInterval(renderSeconds, 250);

    // Both attributes change per update; only restart the arc for a new deadline.
    if (this.#renderedRetryAt === retryAt) return;
    this.#renderedRetryAt = retryAt;

    countdown.classList.remove("is-connecting", "is-waiting");
    countdown.style.setProperty(
      "--retry-duration",
      `${Math.max(0, retryAt - Date.now())}ms`,
    );
    // Force the class removal to be applied so the countdown animation restarts.
    void countdown.getBoundingClientRect();
    countdown.classList.add("is-waiting");
  }

  #showConnectionDialog(dialog: HTMLDialogElement) {
    window.clearTimeout(this.#closeDialogTimer);

    if (dialog.classList.contains("is-visible")) return;

    if (!dialog.open) {
      dialog.showModal();
    }

    // Force the scale(0) state to be painted before transitioning to scale(1).
    void dialog.offsetWidth;
    dialog.classList.add("is-visible");
  }

  #hideConnectionDialog(dialog: HTMLDialogElement) {
    if (!dialog.open || !dialog.classList.contains("is-visible")) return;

    dialog.classList.remove("is-visible");
    this.#closeDialogTimer = window.setTimeout(() => {
      if (!dialog.classList.contains("is-visible")) dialog.close();
    }, 200);
  }

  #updateNavigationProgress(state: string) {
    const progress = this.#navigationProgress;
    if (!progress) return;

    window.clearTimeout(this.#navigationCompleteTimer);
    if (state === "pending") {
      progress.classList.remove("is-complete");
      if (!progress.matches(":popover-open")) progress.showPopover();
      return;
    }

    if (state === "complete") {
      progress.classList.add("is-complete");
      this.#navigationCompleteTimer = window.setTimeout(() => {
        progress.hidePopover();
        progress.classList.remove("is-complete");
      }, 180);
      return;
    }

    progress.hidePopover();
    progress.classList.remove("is-complete");
  }
}

window.customElements.define("mayu-ping", MayuPing);

export default MayuPing;
