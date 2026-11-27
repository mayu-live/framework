import html from "./mayu-navigation-progress.html";
import { part, shadowTemplate } from "./shadow";

const stamp = shadowTemplate(html);

export type NavigationProgressState = "pending" | "complete" | null;

// The bar along the top of the page while a navigation is under way. It is
// a popover, so it is drawn above everything else on the page.
export default class MayuNavigationProgress extends HTMLElement {
  #bar = part<HTMLDivElement>(stamp(this), "bar");
  #state: NavigationProgressState = null;
  #completeTimer?: number;
  #shown = false;

  set state(state: NavigationProgressState) {
    this.#state = state;
    this.#render();
  }

  connectedCallback() {
    this.#render();
  }

  disconnectedCallback() {
    window.clearTimeout(this.#completeTimer);
    // Leaving the document hides a popover.
    this.#shown = false;
    this.#bar.classList.remove("is-complete");
  }

  #render() {
    // A popover can only be shown while it is in the document.
    if (!this.isConnected) return;

    const bar = this.#bar;
    window.clearTimeout(this.#completeTimer);

    if (this.#state === "pending") {
      bar.classList.remove("is-complete");
      if (!this.#shown) bar.showPopover();
      this.#shown = true;
      return;
    }

    if (this.#state === "complete") {
      // Let the bar fill up and fade before it goes away.
      bar.classList.add("is-complete");
      this.#completeTimer = window.setTimeout(() => this.#hide(), 180);
      return;
    }

    this.#hide();
  }

  #hide() {
    this.#bar.classList.remove("is-complete");
    if (!this.#shown) return;
    this.#shown = false;
    this.#bar.hidePopover();
  }
}

customElements.define("mayu-navigation-progress", MayuNavigationProgress);
