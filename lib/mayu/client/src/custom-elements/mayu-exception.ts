import html from "./mayu-exception.html";

const template = document.createElement("template");
template.innerHTML = html;

class MayuException extends HTMLElement {
  dialog?: HTMLDialogElement;

  connectedCallback() {
    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.appendChild(template.content.cloneNode(true));

    this.dialog = this.shadowRoot!.querySelector("dialog") as HTMLDialogElement;

    this.dialog!.showModal();
  }

  disconnectedCallback() {
    this.dialog?.close();
  }
}

window.customElements.define("mayu-exception", MayuException);

export default MayuException;
