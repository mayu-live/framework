import html from "./mayu-exception.html";

const template = document.createElement("template");
template.innerHTML = html;

export default class MayuException extends HTMLElement {
  dialog?: HTMLDialogElement;

  connectedCallback() {
    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.appendChild(template.content.cloneNode(true));

    this.dialog = this.shadowRoot!.querySelector<HTMLDialogElement>("dialog")!;

    this.dialog!.addEventListener("close", this.remove);
    this.dialog!.showModal();
  }

  disconnectedCallback() {
    this.dialog?.close();
  }
}

window.customElements.define("mayu-exception", MayuException);
