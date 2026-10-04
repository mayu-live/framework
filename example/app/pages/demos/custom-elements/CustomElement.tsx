import styles from "./CustomElement.css";

export default class CustomElement extends HTMLElement {
  static observedAttributes = ["color"];

  #outputEl: HTMLSpanElement;

  constructor() {
    super();

    const shadowRoot = this.attachShadow({ mode: "open" });

    shadowRoot.adoptedStyleSheets = [styles];

    shadowRoot.replaceChildren(
      <>
        <h2>Custom element</h2>
        <p>
          Hello world, from a custom element with a custom background color.
        </p>
        <p>
          Current color: <output />
        </p>
      </>,
    );

    this.#outputEl = shadowRoot.querySelector("output") as HTMLOutputElement;
  }

  connectedCallback() {
    // The host is server-rendered, so the browser may have computed its style
    // before this class was defined. @starting-style only applies on the first
    // render, so flip through display: none to make the next render count.
    this.style.display = "none";
    void this.offsetHeight;
    this.style.display = "";
  }

  attributeChangedCallback(
    name: string,
    oldValue: string | null,
    newValue: string | null,
  ) {
    if (oldValue === newValue || !newValue) return;

    if (name === "color") {
      this.#outputEl.textContent = newValue;
      this.style.setProperty("--background-color", newValue);
    }
  }
}
