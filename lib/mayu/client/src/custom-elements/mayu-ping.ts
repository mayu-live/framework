import html from "./mayu-ping.html";

const template = document.createElement("template");
template.innerHTML = html;

class MayuPing extends HTMLElement {
  #div?: HTMLDivElement;
  #ping?: HTMLSpanElement;
  #disconnectDialog?: HTMLDialogElement;

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
    this.#disconnectDialog?.addEventListener("cancel", (event) => {
      // Keep this modal non-cancelable while disconnected.
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
        this.#updateDisconnectedDialog(newValue);
        break;
    }
  }

  #updateDisconnectedDialog(status: string) {
    const dialog = this.#disconnectDialog;
    if (!dialog) return;

    if (status === "disconnected") {
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
