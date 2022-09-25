import html from "./mayu-progress-bar.html";

const template = document.createElement("template");
template.innerHTML = html;

class ProgressBar extends HTMLElement {
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
    console.log("attributeChangedCallback", name, newValue);
    if (name === "progress") {
      switch (Number(newValue)) {
        case 0:
          this.progress!.removeAttribute("hidden");
          break;
        case 100:
          this.progress!.setAttribute("hidden", "");
          console.log("hiding", this.progress);
          break;
        default:
          this.progress!.removeAttribute("hidden");
          break;
      }
    }
  }
}

export default ProgressBar;
