import html from "./mayu-progress-bar.html";

const template = document.createElement("template");
template.innerHTML = html;

class ProgressBar extends HTMLElement {
  progress: HTMLDivElement | null = null;
  value: HTMLDivElement | null = null;

  static observedAttributes = ["progress"];

  connectedCallback() {
    const shadowRoot = this.attachShadow({ mode: "open" });

    shadowRoot.appendChild(
      template.content.cloneNode(true)
    ) as DocumentFragment;

    this.progress = shadowRoot.querySelector(".progress");
    this.value = shadowRoot.querySelector(".value");
  }

  timeout?: number;

  attributeChangedCallback(name: string, oldValue: string, newValue: string) {
    if (name === "progress") {
      this.value!.style.setProperty("width", `${newValue}%`);

      switch (Number(newValue)) {
        case 0:
          // this.progress!.setAttribute('hide', '')
          this.progress!.style.setProperty("opacity", "1");
          clearTimeout(this.timeout);
          break;
        case 100:
          // this.progress!.removeAttribute('hide')
          this.later(() => {
            this.progress!.style.setProperty("opacity", "0");
          }, 200);
          break;
        default:
          this.later(() => {
            const width =
              Number(this.value!.style.getPropertyValue("width")) + 10;
            this.value!.style.setProperty("width", width);
          }, 10 + Math.random() * 50);
        // this.progress!.style.setProperty('opacity', '1')
        // this.progress!.removeAttribute('hide')
      }
    }
  }

  later(cb: () => void, ms: number) {
    clearTimeout(this.timeout);
    this.timeout = setTimeout(cb, ms);
  }
}

export default ProgressBar;
