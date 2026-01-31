import html from "./mayu-ping.html";

const template = document.createElement("template");
template.innerHTML = html;

class MayuPing extends HTMLElement {
  #div?: HTMLDivElement;
  #ping?: HTMLSpanElement;

  static observedAttributes = ["ping", "status"];

  connectedCallback() {
    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.replaceChildren(template.content.cloneNode(true));

    this.#div = this.shadowRoot!.querySelector(".mayu-ping") as HTMLDivElement;
    this.#ping = this.shadowRoot!.querySelector(".ping") as HTMLSpanElement;

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
        break;
    }
  }
}

window.customElements.define("mayu-ping", MayuPing);

export default MayuPing;
