import html from "./mayu-alert.html";

const template = document.createElement("template");
template.innerHTML = html;

class MayuAlert extends HTMLElement {
  #dialog: HTMLDialogElement;
  #message: HTMLParagraphElement;
  #button: HTMLButtonElement;

  static observedAttributes = ["message"];

  constructor() {
    super();

    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.appendChild(
      template.content.cloneNode(true)
    ) as DocumentFragment;

    this.#dialog = this.shadowRoot!.querySelector(
      "dialog"
    ) as HTMLDialogElement;

    this.#button = this.shadowRoot!.querySelector(
      "button"
    ) as HTMLButtonElement;

    this.#message = this.shadowRoot!.getElementById(
      "message"
    ) as HTMLParagraphElement;

    this.#dialog.addEventListener("close", () => this.remove());
  }

  connectedCallback() {
    this.#dialog.showModal();
    this.#message.textContent = this.getAttribute("message");
    this.#button.focus();
  }

  attributeChangedCallback(name: string, oldValue: string, newValue: string) {
    switch (name) {
      case "message":
        this.#message.textContent = String(newValue);
        break;
      default:
        break;
    }
  }

  disconnectedCallback() {
    this.#dialog.close();
  }
}

window.customElements.define("mayu-alert", MayuAlert);

export default MayuAlert;
