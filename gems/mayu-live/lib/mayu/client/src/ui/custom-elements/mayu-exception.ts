import type { ErrorReport, SourceLine, TreeNode } from "../error-report";
import h from "../h";
import html from "./mayu-exception.html";
import { part, shadowTemplate } from "./shadow";

const stamp = shadowTemplate(html);

// The error overlay: a modal dialog that shows one ErrorReport. Everything
// it draws lives in its shadow root, out of reach of the page's styles.
// Closing the dialog removes the element.
export default class MayuException extends HTMLElement {
  #root = stamp(this);
  #dialog = part<HTMLDialogElement>(this.#root, "dialog");
  #backtrace = part<HTMLUListElement>(this.#root, "backtrace");

  constructor() {
    super();

    part(this.#root, "close").addEventListener("click", () =>
      this.#dialog.close(),
    );
    this.#dialog.addEventListener("close", () => this.remove());

    // The frames through Mayu are hidden until the checkbox asks for them.
    const checkbox = part<HTMLInputElement>(this.#root, "framework-checkbox");
    checkbox.addEventListener("change", () => {
      this.#backtrace.classList.toggle("show-framework", checkbox.checked);
    });
  }

  set report(report: ErrorReport) {
    part(this.#root, "type").textContent = report.type;
    part(this.#root, "location").textContent = report.location;
    part(this.#root, "message").textContent = report.message;

    this.#list(
      "hints",
      report.hints.map((hint) => h("li", [hint], { class: "hint-item" })),
    );
    this.#list("source", sourceItems(report.source));
    this.#list(
      "tree",
      report.tree.map((nodes, depth) => {
        const item = h("li", treeLine(nodes), { class: "tree-item" });
        item.style.setProperty("--depth", String(depth));
        return item;
      }),
    );
    this.#list(
      "backtrace",
      report.backtrace.map((frame) =>
        h("li", [frame.text], { class: TRACE_CLASS[frame.kind] }),
      ),
    );

    // The label says how many frames the checkbox would add.
    const frames = report.backtrace.filter(
      (frame) => frame.kind === "framework",
    ).length;
    part<HTMLElement>(this.#root, "framework-toggle").hidden = frames === 0;
    part(this.#root, "framework-count").textContent =
      `Show ${frames} more frames through Mayu`;
  }

  connectedCallback() {
    if (!this.#dialog.open) this.#dialog.showModal();

    // Long files would otherwise open scrolled to the top, away from the
    // error. Not every environment implements scrollIntoView.
    this.#root
      .querySelector(".source-line.is-interesting")
      ?.scrollIntoView?.({ block: "center" });
  }

  disconnectedCallback() {
    this.#dialog.close();
  }

  // Fills one list of the report. A build error has no backtrace or tree
  // path, and often no hints; an empty section would just be noise.
  #list(id: string, items: HTMLElement[]) {
    const list = part<HTMLElement>(this.#root, id);
    list.replaceChildren(...items);
    list.closest("section")!.hidden = items.length === 0;
  }
}

const TRACE_CLASS = {
  module: "trace-item is-interesting",
  app: "trace-item",
  framework: "trace-item is-framework",
};

// Every line carries its own number. The line the error names is followed
// by a caret under the offending column.
function sourceItems(lines: SourceLine[]) {
  const gutter = String(lines.length).length;

  return lines.flatMap((line) => {
    const number = String(line.number).padStart(gutter, " ");
    const items = [
      h("li", [`${number}  ${line.text}`], {
        class: line.marked ? "source-line is-interesting" : "source-line",
      }),
    ];

    if (line.caret !== null) {
      const indent = " ".repeat(gutter + 2 + Math.max(line.caret - 1, 0));
      items.push(h("li", [`${indent}^`], { class: "source-caret" }));
    }

    return items;
  });
}

// "%body > %main > %Page (app:/pages/+page.haml)"
function treeLine(nodes: TreeNode[]) {
  return nodes.flatMap((node, index) => {
    const kind = node.path ? "component" : "tag";

    return [
      index > 0 && h("span", [" > "], { class: "tree-path" }),
      // Only tags get the sigil; names like "#text" do not.
      !node.name.startsWith("#") &&
        h("span", ["%"], { class: `tree-${kind}-sigil` }),
      h("span", [node.name], { class: `tree-${kind}` }),
      node.path && h("span", [` (${node.path})`], { class: "tree-path" }),
    ];
  });
}

customElements.define("mayu-exception", MayuException);
