import html from "./mayu-ping.html";

const template = document.createElement("template");
template.innerHTML = html;

class MayuPing extends HTMLElement {
  div?: HTMLDivElement;
  ping?: HTMLSpanElement;
  region?: HTMLSpanElement;

  static observedAttributes = ["ping", "region", "status"];

  connectedCallback() {
    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.appendChild(
      template.content.cloneNode(true)
    ) as DocumentFragment;

    this.div = this.shadowRoot!.querySelector(".mayu-ping") as HTMLDivElement;
    this.ping = this.shadowRoot!.querySelector(".ping") as HTMLSpanElement;
    this.region = this.shadowRoot!.querySelector(".region") as HTMLSpanElement;
  }

  attributeChangedCallback(name: string, oldValue: string, newValue: string) {
    switch (name) {
      case "ping":
        if (!this.ping) break;
        this.ping.textContent = newValue;
        break;
      case "region":
        if (!this.region) break;
        this.region.textContent = newValue;
        break;
      case "status":
        if (!this.div) break;

        if (oldValue && oldValue !== newValue) {
          this.div!.classList.remove(`status-${oldValue}`);
        }
        if (newValue) {
          this.div!.classList.add(`status-${newValue}`);
        }
        break;
    }
  }
}

window.customElements.define("mayu-ping", MayuPing);

export default MayuPing;
