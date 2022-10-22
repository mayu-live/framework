import html from "./mayu-log.html";
import h from "../h";
import { stringifyJSON } from "../utils";

const template = document.createElement("template");
template.innerHTML = html;

class LogComponent extends HTMLElement {
  log?: HTMLTableSectionElement;

  connectedCallback() {
    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.appendChild(
      template.content.cloneNode(true)
    ) as DocumentFragment;

    this.log = this.shadowRoot!.querySelector(
      ".log"
    ) as HTMLTableSectionElement;

    (
      this.shadowRoot!.querySelector(".clear-button") as HTMLButtonElement
    ).addEventListener("click", () => {
      this.log!.innerHTML = "";
    });
  }

  addEntry(id: string, event: string, payload: any) {
    this.log!.appendChild(
      h("tr", [
        h("td", [id]),
        h("td", [event]),
        h("td", [h("pre", [stringifyJSON(payload)])]),
      ])
    );
  }
}

export default LogComponent;
