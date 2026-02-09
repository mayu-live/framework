import html from "./mayu-ping.html";

const template = document.createElement("template");
template.innerHTML = html;

class MayuPing extends HTMLElement {
  #div?: HTMLDivElement;
  #ping?: HTMLSpanElement;
  #disconnectDialog?: HTMLDialogElement;
  #disconnectTitle?: HTMLParagraphElement;
  #disconnectText?: HTMLParagraphElement;

  static observedAttributes = ["ping", "status"];

  connectedCallback() {
    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.replaceChildren(template.content.cloneNode(true));

    this.#div = this.shadowRoot!.querySelector(".mayu-ping") as HTMLDivElement;
    this.#ping = this.shadowRoot!.querySelector(".ping") as HTMLSpanElement;
    this.#disconnectDialog = this.shadowRoot!.querySelector(
      ".disconnect-dialog"
    ) as HTMLDialogElement;
    this.#disconnectTitle = this.shadowRoot!.querySelector(
      ".disconnect-title"
    ) as HTMLParagraphElement;
    this.#disconnectText = this.shadowRoot!.querySelector(
      ".disconnect-text"
    ) as HTMLParagraphElement;
    this.#disconnectDialog?.addEventListener("cancel", (event) => {
      // Keep this modal non-cancelable while connection is unavailable.
      event.preventDefault();
    });

    const status = this.getAttribute("status");

    if (status) {
      this.attributeChangedCallback("status", "", status);
    }
  }

  disconnectedCallback() {}

  attributeChangedCallback(name: string, oldValue: string, newValue: string) {
    switch (name) {
      case "ping":
        if (!this.#ping) return;
        this.#ping.textContent = newValue;
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
      if (!dialog.open) {
        dialog.showModal();
      }
      return;
    }

    if (status === "transferring") {
      title.textContent = "Transferring";
      text.textContent = "Trying to restore connection…";
      if (!dialog.open) {
        dialog.showModal();
      }
      return;
    }

    if (dialog.open) {
      dialog.close();
    }
  }
}

window.customElements.define("mayu-ping", MayuPing);

export default MayuPing;
