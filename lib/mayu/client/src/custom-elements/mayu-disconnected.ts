import html from "./mayu-disconnected.html";

const template = document.createElement("template");
template.innerHTML = html;

class MayuDisconnected extends HTMLElement {
  dialog?: HTMLDialogElement;
  reason?: HTMLParagraphElement;

  static observedAttributes = ["reason"];

  constructor() {
    super();

    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.appendChild(
      template.content.cloneNode(true)
    ) as DocumentFragment;

    this.dialog = this.shadowRoot!.querySelector("dialog") as HTMLDialogElement;
    this.reason = this.shadowRoot!.getElementById(
      "reason"
    ) as HTMLParagraphElement;
  }

  connectedCallback() {
    this.dialog!.showModal();
  }

  attributeChangedCallback(name: string, oldValue: string, newValue: string) {
    switch (name) {
      case "reason":
        if (!this.reason) break;
        this.reason.textContent = String(newValue);
        break;
      default:
        break;
    }
  }

  disconnectedCallback() {
    this.dialog?.close();
  }
}

window.customElements.define("mayu-disconnected", MayuDisconnected);

export default MayuDisconnected;
