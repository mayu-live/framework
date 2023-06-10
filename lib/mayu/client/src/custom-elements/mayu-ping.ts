import html from "./mayu-ping.html";

const template = document.createElement("template");
template.innerHTML = html;

const REGION_NAMES: Record<string, string> = {
  ams: "Amsterdam, Netherlands",
  arn: "Stockholm, Sweden",
  atl: "Atlanta, Georgia (US)",
  bog: "Bogotá, Colombia",
  bom: "Mumbai, India",
  bos: "Boston, Massachusetts (US)",
  cdg: "Paris, France",
  den: "Denver, Colorado (US)",
  dfw: "Dallas, Texas (US)",
  ewr: "Secaucus, NJ (US)",
  eze: "Ezeiza, Argentina",
  fra: "Frankfurt, Germany",
  gdl: "Guadalajara, Mexico",
  gig: "Rio de Janeiro, Brazil",
  gru: "Sao Paulo, Brazil",
  hkg: "Hong Kong, Hong Kong",
  iad: "Ashburn, Virginia (US)",
  jnb: "Johannesburg, South Africa",
  lax: "Los Angeles, California (US)",
  lhr: "London, United Kingdom",
  maa: "Chennai (Madras), India",
  mad: "Madrid, Spain",
  mia: "Miami, Florida (US)",
  nrt: "Tokyo, Japan",
  ord: "Chicago, Illinois (US)",
  otp: "Bucharest, Romania",
  phx: "Phoenix, Arizona (US)",
  qro: "Querétaro, Mexico",
  scl: "Santiago, Chile",
  sea: "Seattle, Washington (US)",
  sin: "Singapore, Singapore",
  sjc: "San Jose, California (US)",
  syd: "Sydney, Australia",
  waw: "Warsaw, Poland",
  yul: "Montreal, Canada",
  yyz: "Toronto, Canada",
};

class MayuPing extends HTMLElement {
  #div?: HTMLDivElement;
  #ping?: HTMLSpanElement;
  #instance?: HTMLSpanElement;
  #region?: HTMLSpanElement;

  static observedAttributes = ["ping", "region", "status"];

  connectedCallback() {
    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.appendChild(
      template.content.cloneNode(true)
    ) as DocumentFragment;

    this.#div = this.shadowRoot!.querySelector(".mayu-ping") as HTMLDivElement;
    this.#ping = this.shadowRoot!.querySelector(".ping") as HTMLSpanElement;
    this.#instance = this.shadowRoot!.querySelector(
      ".instance"
    ) as HTMLSpanElement;
    this.#region = this.shadowRoot!.querySelector(".region") as HTMLSpanElement;
  }

  attributeChangedCallback(name: string, oldValue: string, newValue: string) {
    switch (name) {
      case "ping":
        this.#ping!.textContent = newValue;
        break;
      case "instance":
        this.#instance!.textContent = newValue;
        break;
      case "region":
        this.#region!.textContent = REGION_NAMES[newValue] || newValue;
        break;
      case "status":
        if (oldValue && oldValue !== newValue) {
          this.#div!.classList.remove(`status-${oldValue}`);
        }
        if (newValue) {
          this.#div!.classList.add(`status-${newValue}`);
        }
        break;
    }
  }
}

window.customElements.define("mayu-ping", MayuPing);

export default MayuPing;
