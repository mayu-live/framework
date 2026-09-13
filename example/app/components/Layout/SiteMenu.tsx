// Wraps the site navigation. The menu itself is a native popover, so opening
// and closing needs no JavaScript. This element closes the popover in two
// cases the browser does not handle on its own:
//
// - after a link inside it is clicked, because Mayu navigates without
//   reloading the page and the popover would otherwise stay open
// - when the viewport grows past the breakpoint where the navigation turns
//   into an inline sidebar, because a popover in the top layer would keep
//   rendering above everything else
//
// The breakpoint is passed in as the "breakpoint" attribute so it lives next
// to the matching media query in the layout's CSS.
export default class SiteMenu extends HTMLElement {
  #wide: MediaQueryList | null = null;

  #onClick = (event: Event) => {
    const target = event.target as Element | null;
    if (!target?.closest("a[href]")) return;

    this.#hide();
  };

  #onBreakpointChange = () => {
    if (this.#wide?.matches) this.#hide();
  };

  #hide() {
    const popover = this.querySelector<HTMLElement>("[popover]");
    if (popover?.matches(":popover-open")) popover.hidePopover();
  }

  connectedCallback() {
    this.addEventListener("click", this.#onClick);

    const breakpoint = this.getAttribute("breakpoint");
    if (breakpoint) {
      this.#wide = window.matchMedia(breakpoint);
      this.#wide.addEventListener("change", this.#onBreakpointChange);
      window.addEventListener("resize", this.#onBreakpointChange);
    }
  }

  disconnectedCallback() {
    this.removeEventListener("click", this.#onClick);
    this.#wide?.removeEventListener("change", this.#onBreakpointChange);
    window.removeEventListener("resize", this.#onBreakpointChange);
    this.#wide = null;
  }
}
