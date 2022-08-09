import html from "./mayu-ping.html";

const template = document.createElement("template");
template.innerHTML = html;

class PingComponent extends HTMLElement {
  div?: HTMLDivElement;
  ping?: HTMLSpanElement;
  region?: HTMLSpanElement;

  static observedAttributes = ["ping", "region"];

  connectedCallback() {
    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.appendChild(
      template.content.cloneNode(true)
    ) as DocumentFragment;

    this.ping = this.shadowRoot!.querySelector(".ping") as HTMLSpanElement;
    this.region = this.shadowRoot!.querySelector(".region") as HTMLSpanElement;
  }

  attributeChangedCallback(name: string, oldValue: string, newValue: string) {
    console.log(name, oldValue, newValue);
    switch (name) {
      case "ping":
        this.ping!.textContent = newValue;
        break;
      case "region":
        this.region!.textContent = newValue;
        break;
    }
  }
}

export default PingComponent;
