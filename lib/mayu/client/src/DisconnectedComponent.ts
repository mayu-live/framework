import html from './DisconnectedComponent.html'

const template = document.createElement("template");
template.innerHTML = html

class DisconnectedComponent extends HTMLElement {
  dialog?: HTMLDialogElement;

  connectedCallback() {
    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.appendChild(
      template.content.cloneNode(true)
    ) as DocumentFragment;

    this.dialog = this.shadowRoot!.querySelector("dialog") as HTMLDialogElement;

    this.dialog?.showModal();
  }

  disconnectedCallback() {
    this.dialog?.close();
  }
}

export default DisconnectedComponent;
