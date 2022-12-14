import html from "./mayu-progress-bar.html";

const template = document.createElement("template");
template.innerHTML = html;

class MayuProgressBar extends HTMLElement {
  progress: HTMLDivElement | null = null;

  static observedAttributes = ["progress"];

  connectedCallback() {
    const shadowRoot = this.attachShadow({ mode: "open" });

    shadowRoot.appendChild(
      template.content.cloneNode(true)
    ) as DocumentFragment;

    this.progress = shadowRoot.querySelector(".progress")!;
  }

  attributeChangedCallback(name: string, oldValue: string, newValue: string) {
    if (name === "progress") {
      switch (Number(newValue)) {
        case 0:
          this.progress!.removeAttribute("hidden");
          break;
        case 100:
          this.progress!.setAttribute("hidden", "");
          break;
        default:
          this.progress!.removeAttribute("hidden");
          break;
      }
    }
  }
}

window.customElements.define("mayu-progress-bar", MayuProgressBar);

export default MayuProgressBar;
