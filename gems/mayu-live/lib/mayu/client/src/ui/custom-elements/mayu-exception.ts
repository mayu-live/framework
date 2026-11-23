import html from "./mayu-exception.html";

const template = document.createElement("template");
template.innerHTML = html;

export default class MayuException extends HTMLElement {
  dialog?: HTMLDialogElement;
  closeButton?: HTMLButtonElement;

  connectedCallback() {
    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.appendChild(template.content.cloneNode(true));

    this.dialog = this.shadowRoot!.querySelector<HTMLDialogElement>("dialog")!;
    this.closeButton =
      this.shadowRoot!.querySelector<HTMLButtonElement>(
        "[data-action='close']",
      ) || undefined;

    this.closeButton?.addEventListener("click", () => this.dialog?.close());
    this.dialog!.addEventListener("close", () => this.remove());

    this.hideEmptySections();
    this.setupFrameworkFrames();

    if (!this.dialog!.open) {
      this.dialog!.showModal();
    }
  }

  // The frames through Mayu are hidden until the checkbox asks for them;
  // its label says how many there are.
  private setupFrameworkFrames() {
    const root = this.shadowRoot!;
    const toggle = root.querySelector<HTMLElement>("[data-framework-toggle]");
    const checkbox = root.querySelector<HTMLInputElement>(
      "[data-action='toggle-framework-frames']",
    );
    const count = root.querySelector<HTMLElement>("[data-framework-count]");
    const slot = root.querySelector<HTMLSlotElement>("slot[name='backtrace']");
    if (!toggle || !checkbox || !count || !slot) return;

    checkbox.addEventListener("change", () => {
      this.toggleAttribute("show-framework-frames", checkbox.checked);
    });

    const sync = () => {
      const frames = slot
        .assignedElements()
        .filter((item) => item.classList.contains("is-framework")).length;
      toggle.hidden = frames === 0;
      count.textContent = `Show ${frames} more frames through Mayu`;
    };

    slot.addEventListener("slotchange", sync);
    sync();
  }

  disconnectedCallback() {
    this.dialog?.close();
  }

  // A build error has no backtrace or tree path worth showing, and often no
  // hints. Empty panels would just be noise.
  private hideEmptySections() {
    this.shadowRoot
      ?.querySelectorAll<HTMLElement>("[data-section]")
      .forEach((section) => {
        const slot = section.querySelector("slot");
        if (!slot) return;

        const sync = () => {
          section.hidden = slot.assignedNodes().length === 0;
        };

        slot.addEventListener("slotchange", sync);
        sync();
      });
  }
}

window.customElements.define("mayu-exception", MayuException);
