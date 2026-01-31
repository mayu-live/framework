import html from "./mayu-exception.html";

const template = document.createElement("template");
template.innerHTML = html;

export default class MayuException extends HTMLElement {
  dialog?: HTMLDialogElement;
  closeButton?: HTMLButtonElement;

  connectedCallback() {
    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.appendChild(template.content.cloneNode(true));

    this.dialog = this.shadowRoot!.querySelector<HTMLDialogElement>("dialog")!;
    this.closeButton = this.shadowRoot!.querySelector<HTMLButtonElement>(
      "[data-action='close']"
    );

    this.closeButton?.addEventListener("click", () => this.dialog?.close());
    this.dialog!.addEventListener("close", () => this.remove());

    if (!this.dialog!.open) {
      this.dialog!.showModal();
    }
  }

  disconnectedCallback() {
    this.dialog?.close();
  }
}

window.customElements.define("mayu-exception", MayuException);
