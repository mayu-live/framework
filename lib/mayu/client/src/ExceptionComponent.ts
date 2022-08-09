import html from "./ExceptionComponent.html";

const template = document.createElement("template");
template.innerHTML = html;

class ExceptionComponent extends HTMLElement {
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

export default ExceptionComponent;
