// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Draws boxes over DOM nodes in the page, like the Elements panel does when
// hovering a node. Extensions can't use that overlay, so this one lives in
// the page: a closed shadow root in an element appended to <html>, which
// Mayu doesn't know about. It is only in the DOM while something is
// highlighted.

const STYLE = `
  :host {
    all: initial;
    position: fixed;
    inset: 0;
    width: 100vw;
    height: 100vh;
    margin: 0;
    padding: 0;
    border: 0;
    background: transparent;
    overflow: visible;
    pointer-events: none;
    z-index: 2147483647;
  }
  .box {
    position: fixed;
    box-sizing: border-box;
    background: rgba(111, 168, 220, 0.5);
    outline: 1px solid rgba(111, 168, 220, 0.9);
  }
  .label {
    position: fixed;
    padding: 2px 6px;
    border-radius: 3px;
    background: #fff;
    color: #333;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.3);
    font: 11px/1.4 ui-monospace, Menlo, Consolas, monospace;
    white-space: nowrap;
  }
  .name {
    color: #8b2fc9;
  }
  .size {
    color: #6e6e6e;
    margin-left: 6px;
  }
`;

// Room the label needs above the box before it goes below it instead.
const LABEL_HEIGHT = 20;

export default class Highlighter {
  #lookup: (id: string) => Node | null;
  #host: HTMLElement | null = null;
  #root: ShadowRoot | null = null;
  #ids: string[] = [];
  #label = "";
  #frame: number | null = null;

  constructor(lookup: (id: string) => Node | null) {
    this.#lookup = lookup;
  }

  show(ids: string[], label: string) {
    this.#ids = ids;
    this.#label = label;
    if (this.#frame === null) this.#draw();
  }

  hide() {
    this.#ids = [];
    if (this.#frame !== null) cancelAnimationFrame(this.#frame);
    this.#frame = null;
    this.#host?.remove();
  }

  // Redraws every frame while shown, since the page can scroll, resize and
  // rerender under the highlight. Nodes are looked up by id each time, so a
  // replaced node is followed too.
  #draw() {
    const rects = this.#ids
      .map((id) => this.#lookup(id))
      .filter((node): node is Node => node !== null)
      .map(rectOf)
      .filter((rect): rect is DOMRect => rect !== null);

    if (rects.length === 0) {
      this.#host?.remove();
    } else {
      this.#render(rects);
    }

    this.#frame = requestAnimationFrame(() => this.#draw());
  }

  #render(rects: DOMRect[]) {
    const root = this.#mount();
    const boxes = rects.map((rect) => {
      const box = document.createElement("div");
      box.className = "box";
      Object.assign(box.style, {
        left: `${rect.left}px`,
        top: `${rect.top}px`,
        width: `${rect.width}px`,
        height: `${rect.height}px`,
      });
      return box;
    });

    const left = Math.min(...rects.map((rect) => rect.left));
    const top = Math.min(...rects.map((rect) => rect.top));
    const right = Math.max(...rects.map((rect) => rect.right));
    const bottom = Math.max(...rects.map((rect) => rect.bottom));

    const label = document.createElement("div");
    label.className = "label";
    const name = document.createElement("span");
    name.className = "name";
    name.textContent = this.#label;
    const size = document.createElement("span");
    size.className = "size";
    size.textContent = `${round(right - left)} × ${round(bottom - top)}`;
    label.append(name, size);
    Object.assign(label.style, {
      left: `${Math.max(left, 0)}px`,
      top:
        top >= LABEL_HEIGHT
          ? `${top - LABEL_HEIGHT}px`
          : `${Math.min(bottom + 2, innerHeight - LABEL_HEIGHT)}px`,
    });

    root.replaceChildren(root.firstChild!, ...boxes, label);
  }

  #mount() {
    if (!this.#host || !this.#root) {
      this.#host = document.createElement("mayu-devtools-highlight");
      this.#root = this.#host.attachShadow({ mode: "closed" });
      const style = document.createElement("style");
      style.textContent = STYLE;
      this.#root.append(style);
    }

    // Mayu removes children of <html> it doesn't know about when it
    // replaces its children.
    if (!this.#host.isConnected) document.documentElement.append(this.#host);
    return this.#root;
  }
}

function rectOf(node: Node): DOMRect | null {
  if (node instanceof Element) return node.getBoundingClientRect();

  if (node instanceof Text) {
    const range = document.createRange();
    range.selectNodeContents(node);
    return range.getBoundingClientRect();
  }

  return null;
}

function round(value: number) {
  return Math.round(value * 100) / 100;
}
