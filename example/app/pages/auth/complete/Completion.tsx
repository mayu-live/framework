export default class Completion extends HTMLElement {
  connectedCallback() {
    if (typeof BroadcastChannel === "undefined") return;
    const channel = new BroadcastChannel("mayu-oidc-demo");
    channel.postMessage({
      type: "mayu:oidc:complete",
      error: this.getAttribute("error") === "signin",
    });
    channel.close();
    if (this.getAttribute("error") !== "signin") window.close();
  }
}
