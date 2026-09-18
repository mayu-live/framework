import html from "./mayu-ping.html";

const template = document.createElement("template");
template.innerHTML = html;

class MayuPing extends HTMLElement {
  #div?: HTMLDivElement;
  #ping?: HTMLSpanElement;
  #disconnectDialog?: HTMLDialogElement;
  #disconnectTitle?: HTMLParagraphElement;
  #disconnectText?: HTMLParagraphElement;
  #updateViewportOffset = () => {
    const ping = this.#div;
    const viewport = window.visualViewport;
    if (!ping || !viewport) return;

    // Fixed-positioned elements use the layout viewport. Compensate when the
    // visual viewport is shortened by mobile browser controls or a keyboard.
    const bottom = Math.max(
      0,
      document.documentElement.clientHeight -
        viewport.height -
        viewport.offsetTop,
    );
    const right = Math.max(
      0,
      document.documentElement.clientWidth -
        viewport.width -
        viewport.offsetLeft,
    );

    ping.style.setProperty("--mayu-visual-viewport-bottom", `${bottom}px`);
    ping.style.setProperty("--mayu-visual-viewport-right", `${right}px`);
  };

  static observedAttributes = ["ping", "status"];

  connectedCallback() {
    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" });
    }

    this.shadowRoot!.replaceChildren(template.content.cloneNode(true));

    this.#div = this.shadowRoot!.querySelector(".mayu-ping") as HTMLDivElement;
    this.#ping = this.shadowRoot!.querySelector(".ping") as HTMLSpanElement;
    this.#disconnectDialog = this.shadowRoot!.querySelector(
      ".disconnect-dialog",
    ) as HTMLDialogElement;
    this.#disconnectTitle = this.shadowRoot!.querySelector(
      ".disconnect-title",
    ) as HTMLParagraphElement;
    this.#disconnectText = this.shadowRoot!.querySelector(
      ".disconnect-text",
    ) as HTMLParagraphElement;
    this.#showInTopLayer();
    this.#updateViewportOffset();
    window.visualViewport?.addEventListener(
      "resize",
      this.#updateViewportOffset,
    );
    window.visualViewport?.addEventListener(
      "scroll",
      this.#updateViewportOffset,
    );
    this.#disconnectDialog?.addEventListener("cancel", (event) => {
      // Keep this modal non-cancelable while connection is unavailable.
      event.preventDefault();
    });

    const status = this.getAttribute("status");

    if (status) {
      this.attributeChangedCallback("status", "", status);
    }
  }

  disconnectedCallback() {
    window.visualViewport?.removeEventListener(
      "resize",
      this.#updateViewportOffset,
    );
    window.visualViewport?.removeEventListener(
      "scroll",
      this.#updateViewportOffset,
    );
  }

  attributeChangedCallback(name: string, oldValue: string, newValue: string) {
    switch (name) {
      case "ping":
        if (!this.#ping) return;
        this.#ping.textContent = newValue;
        break;
      case "status":
        const classList = this.#div?.classList;
        if (oldValue && oldValue !== newValue) {
          classList?.remove(`status-${oldValue}`);
        }
        if (newValue) {
          classList?.add(`status-${newValue}`);
        }
        this.#updateConnectionDialog(newValue);
        break;
    }
  }

  #updateConnectionDialog(status: string) {
    const dialog = this.#disconnectDialog;
    const title = this.#disconnectTitle;
    const text = this.#disconnectText;
    if (!dialog || !title || !text) return;

    if (status === "disconnected") {
      title.textContent = "Disconnected";
      text.textContent = "Trying to reconnect…";
      if (!dialog.open) {
        dialog.showModal();
      }
      return;
    }

    if (status === "transferring") {
      title.textContent = "Transferring";
      text.textContent = "Trying to restore connection…";
      if (!dialog.open) {
        dialog.showModal();
      }
      return;
    }

    if (dialog.open) {
      dialog.close();
    }
  }

  #showInTopLayer() {
    const ping = this.#div;
    if (!ping) return;

    // Popovers are promoted above every page stacking context. Older browsers
    // simply keep the fixed-position fallback.
    try {
      ping.showPopover();
    } catch {
      // The Popover API is unavailable, or this element is no longer connected.
    }
  }
}

window.customElements.define("mayu-ping", MayuPing);

export default MayuPing;
