import MayuConnectionDialog from "./mayu-connection-dialog";
import MayuNavigationProgress, {
  type NavigationProgressState,
} from "./mayu-navigation-progress";
import html from "./mayu-ping.html";
import { part, shadowTemplate } from "./shadow";

const stamp = shadowTemplate(html);

// The status of the page's connection. The server renders one <mayu-ping>
// at the end of every body, and `ui/status.ts` sets its attributes:
//
//   ping               the round trip time, as text
//   status             "connected", "disconnected" or "transferring"
//   navigation         "pending" or "complete" while a navigation runs
//   reconnect-attempt  the number of the reconnect attempt
//   reconnect-at       when the next attempt starts, in epoch milliseconds
//
// Attributes, because they can be set before this module has loaded. The
// element draws the badge in the corner itself, and hands the rest to
// <mayu-navigation-progress> and <mayu-connection-dialog> in its shadow
// root.
export default class MayuPing extends HTMLElement {
  static observedAttributes = [
    "ping",
    "status",
    "navigation",
    "reconnect-attempt",
    "reconnect-at",
  ];

  #root = stamp(this);
  #badge = part<HTMLDivElement>(this.#root, "badge");
  #progress = this.#root.appendChild(new MayuNavigationProgress());
  #dialog = this.#root.appendChild(new MayuConnectionDialog());

  // Keeps the badge in the bottom right corner of what is visible, also
  // while the page is zoomed in on.
  #updatePosition = () => {
    const badge = this.#badge;
    const viewport = window.visualViewport;
    const offsetLeft = viewport?.offsetLeft ?? 0;
    const offsetTop = viewport?.offsetTop ?? 0;
    const width = viewport?.width ?? window.innerWidth;
    const height = viewport?.height ?? window.innerHeight;

    badge.style.transform = `translate(${offsetLeft + width - badge.offsetWidth}px, ${offsetTop + height - badge.offsetHeight}px)`;
  };

  connectedCallback() {
    this.#updatePosition();
    window.addEventListener("scroll", this.#updatePosition, { passive: true });
    window.visualViewport?.addEventListener("resize", this.#updatePosition);
    window.visualViewport?.addEventListener("scroll", this.#updatePosition);
  }

  disconnectedCallback() {
    window.removeEventListener("scroll", this.#updatePosition);
    window.visualViewport?.removeEventListener("resize", this.#updatePosition);
    window.visualViewport?.removeEventListener("scroll", this.#updatePosition);
  }

  attributeChangedCallback(
    name: string,
    _old: string | null,
    value: string | null,
  ) {
    switch (name) {
      case "ping":
        this.#badge.textContent = value;
        this.#updatePosition();
        break;
      case "status":
        // The badge takes its colour from the attribute, in the stylesheet.
        this.#dialog.status = value;
        break;
      case "navigation":
        this.#progress.state = value as NavigationProgressState;
        break;
      case "reconnect-attempt":
      case "reconnect-at": {
        const retryAt = this.getAttribute("reconnect-at");
        this.#dialog.setReconnect(
          this.getAttribute("reconnect-attempt"),
          retryAt ? Number(retryAt) : null,
        );
        break;
      }
    }
  }
}

customElements.define("mayu-ping", MayuPing);
