import html from "./mayu-ping.html";

const template = document.createElement("template");
template.innerHTML = html;

class MayuPing extends HTMLElement {
  #div?: HTMLDivElement;
  #ping?: HTMLSpanElement;
  #disconnectDialog?: HTMLDialogElement;
  #disconnectTitle?: HTMLParagraphElement;
  #disconnectText?: HTMLParagraphElement;
  #closeDialogTimer?: number;
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

  static observedAttributes = ["ping", "status"];

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
  }

  disconnectedCallback() {
    window.removeEventListener("scroll", this.#updatePosition);
    window.visualViewport?.removeEventListener("resize", this.#updatePosition);
    window.visualViewport?.removeEventListener("scroll", this.#updatePosition);
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
}

window.customElements.define("mayu-ping", MayuPing);

export default MayuPing;
