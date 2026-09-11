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
    this.closeButton =
      this.shadowRoot!.querySelector<HTMLButtonElement>(
        "[data-action='close']",
      ) || undefined;

    this.closeButton?.addEventListener("click", () => this.dialog?.close());
    this.dialog!.addEventListener("close", () => this.remove());

    this.hideEmptySections();

    if (!this.dialog!.open) {
      this.dialog!.showModal();
    }
  }

  disconnectedCallback() {
    this.dialog?.close();
  }

  // A build error has no backtrace or tree path worth showing, and often no
  // hints. Empty panels would just be noise.
  private hideEmptySections() {
    this.shadowRoot
      ?.querySelectorAll<HTMLElement>("[data-section]")
      .forEach((section) => {
        const slot = section.querySelector("slot");
        if (!slot) return;

        const sync = () => {
          section.hidden = slot.assignedNodes().length === 0;
        };

        slot.addEventListener("slotchange", sync);
        sync();
      });
  }
}

window.customElements.define("mayu-exception", MayuException);
