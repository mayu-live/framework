// Displays a number and tweens to the new value whenever the "value"
// attribute changes.
//
// The server renders the formatted number as light DOM children, so the value
// is visible before this element is defined. Once defined, the element renders
// into a shadow root without a slot, which hides those children. Server
// patches to them keep working, they just aren't shown.
//
// Attributes:
//
// - value: the number to display
// - format: "number" (default), "signed", "bytes" or "percent"
// - suffix: text appended after the number, like " ms"
// - duration: tween duration in milliseconds, defaults to 600

const DEFAULT_DURATION = 600;
const BYTE_UNITS = ["B", "KiB", "MiB", "GiB"];

const integerFormat = new Intl.NumberFormat("en-US", {
  maximumFractionDigits: 0,
  signDisplay: "negative",
});

const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

function easeOutCubic(t: number) {
  return 1 - (1 - t) ** 3;
}

function formatBytes(value: number) {
  const exponent =
    value <= 0
      ? 0
      : Math.min(
          Math.max(Math.floor(Math.log(value) / Math.log(1024)), 0),
          BYTE_UNITS.length - 1,
        );

  return `${(value / 1024 ** exponent).toFixed(1)} ${BYTE_UNITS[exponent]}`;
}

function format(value: number, kind: string | null) {
  switch (kind) {
    case "signed":
      return Math.round(value) > 0
        ? `+${integerFormat.format(value)}`
        : integerFormat.format(value);
    case "bytes":
      return formatBytes(value);
    case "percent":
      return `${Math.round(value)}%`;
    default:
      return integerFormat.format(value);
  }
}

export default class NumberTween extends HTMLElement {
  static observedAttributes = ["value", "format", "suffix"];

  #output: Text;
  #current: number | null = null;
  #frame = 0;

  constructor() {
    super();

    const shadowRoot = this.attachShadow({ mode: "open" });
    this.#output = document.createTextNode("");
    shadowRoot.replaceChildren(this.#output);
  }

  connectedCallback() {
    this.#current = this.#target;
    this.#render(this.#current);
  }

  disconnectedCallback() {
    cancelAnimationFrame(this.#frame);
  }

  attributeChangedCallback(name: string, oldValue: string | null) {
    if (!this.isConnected || this.#current === null) return;

    // requestAnimationFrame doesn't run in hidden documents, so there is
    // nothing to animate.
    if (
      name !== "value" ||
      oldValue === null ||
      reducedMotion.matches ||
      document.hidden
    ) {
      cancelAnimationFrame(this.#frame);
      this.#current = this.#target;
      this.#render(this.#current);
      return;
    }

    this.#tween(this.#current, this.#target);
  }

  get #target() {
    const value = Number(this.getAttribute("value"));
    return Number.isFinite(value) ? value : 0;
  }

  get #duration() {
    const duration = Number(this.getAttribute("duration"));
    return Number.isFinite(duration) && duration > 0
      ? duration
      : DEFAULT_DURATION;
  }

  #tween(from: number, to: number) {
    cancelAnimationFrame(this.#frame);

    const duration = this.#duration;
    const start = performance.now();

    const step = (now: number) => {
      const progress = Math.min((now - start) / duration, 1);
      this.#current = from + (to - from) * easeOutCubic(progress);
      this.#render(this.#current);

      if (progress < 1) {
        this.#frame = requestAnimationFrame(step);
      }
    };

    this.#frame = requestAnimationFrame(step);
  }

  #render(value: number) {
    const suffix = this.getAttribute("suffix") ?? "";
    this.#output.data = format(value, this.getAttribute("format")) + suffix;
  }
}
