import html from "./mayu-disconnected.html";

const template = document.createElement("template");
template.innerHTML = html;

class DisconnectedComponent extends HTMLElement {
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
        console.log("Updating reason", newValue);
        console.log(this.reason);
        console.log(this.dialog);
        if (this.reason) {
          this.reason.textContent = String(newValue);
        }
        break;
      default:
        break;
    }
  }

  disconnectedCallback() {
    this.dialog?.close();
  }
}

export default DisconnectedComponent;
