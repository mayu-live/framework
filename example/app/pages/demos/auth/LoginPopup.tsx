// Keep the browser's ordinary document navigation as the no-JS/blocked-popup
// fallback. Messages only trigger a reload; the server verifies the identity.
export default class LoginPopup extends HTMLElement {
  #channel: BroadcastChannel | null = null;

  #onComplete = (event: MessageEvent) => {
    if (event.data?.type !== "mayu:oidc:complete") return;
    // A location.assign is intercepted as live navigation by Mayu. Reload the
    // document so prepare_session reads the newly issued identity cookie.
    history.replaceState(
      history.state,
      "",
      event.data.error ? "/demos/auth?error=signin" : "/demos/auth",
    );
    window.location.reload();
  };

  #onClick = (event: MouseEvent) => {
    if (
      !this.#channel ||
      event.button !== 0 ||
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey
    )
      return;
    const link = (event.target as Element).closest<HTMLAnchorElement>(
      "a[href]",
    );
    if (!link) return;
    const url = new URL(link.href);
    if (url.origin !== window.location.origin) return;
    const popup = window.open(
      "about:blank",
      "mayu-oidc-login",
      "popup,width=520,height=720",
    );
    if (!popup) return;
    event.preventDefault();
    event.stopPropagation();
    // Do not give the external provider access to the original window.
    // BroadcastChannel allows completion without retaining window.opener.
    popup.opener = null;
    url.searchParams.set("popup", "1");
    popup.location.replace(url);
    popup.focus();
  };

  connectedCallback() {
    if (typeof BroadcastChannel === "undefined") return;
    this.#channel = new BroadcastChannel("mayu-oidc-demo");
    this.#channel.addEventListener("message", this.#onComplete);
    this.addEventListener("click", this.#onClick);
  }

  disconnectedCallback() {
    this.removeEventListener("click", this.#onClick);
    this.#channel?.close();
    this.#channel = null;
  }
}
