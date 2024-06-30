const template = document.createElement("template");

template.innerHTML = `
  <style>
    #root {
      overflow: hidden;
      color: white;
      font-weight: bold;
      border-radius: 2px;
      padding-inline: 1rem;
      margin-block: 1rem;
    }
  </style>
  <div id="root">
    <p>Hello world from a custom element with a custom background color.</p>
    <p>Current color: <span id="color"></span></p>
  </div>
`;

export default class CustomElement extends HTMLElement {
  static observedAttributes = ["color"];

  constructor() {
    super();

    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot.appendChild(template.content.cloneNode(true));
    this.shadowRoot.querySelector("#color").textContent =
      this.getAttribute("color");
  }

  connectedCallback() {
    console.log(this.attributes);
  }

  attributeChangedCallback(name, oldValue, newValue) {
    console.log(`Attribute ${name} has changed.`, oldValue, newValue);

    if (name === "color") {
      this.shadowRoot.querySelector("#color").textContent = newValue;
      this.shadowRoot
        .querySelector("#root")
        .style.setProperty("background-color", newValue);
    }
  }
}
