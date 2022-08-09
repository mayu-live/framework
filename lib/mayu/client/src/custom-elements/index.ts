import MayuDisconnected from "./mayu-disconnected";
import MayuException from "./mayu-exception";
import MayuPing from "./mayu-ping";
import MayuProgressBar from "./mayu-progress-bar";

export default function defineCustomElements() {
  window.customElements.define("mayu-disconnected", MayuDisconnected);
  window.customElements.define("mayu-exception", MayuException);
  window.customElements.define("mayu-ping", MayuPing);
  window.customElements.define("mayu-progress-bar", MayuProgressBar);
}
