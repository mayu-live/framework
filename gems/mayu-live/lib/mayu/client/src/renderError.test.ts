import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";

import renderError from "./renderError";

describe("renderError", () => {
  beforeAll(() => {
    // jsdom does not implement the dialog element's modal methods.
    HTMLDialogElement.prototype.showModal = function () {
      this.open = true;
    };
    HTMLDialogElement.prototype.close = function () {
      if (!this.open) return;
      this.open = false;
      this.dispatchEvent(new Event("close"));
    };
  });

  afterEach(() => {
    document.querySelectorAll("mayu-exception").forEach((element) => {
      element.remove();
    });
    vi.restoreAllMocks();
  });

  it("renders listener errors without source code", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    await renderError(
      "/app/pages/demos/exceptions/+page.haml",
      "NoMatchingPatternError",
      "The callback failed",
      ["/app/pages/demos/exceptions/+page.haml:13:in 'handle_click'"],
      null,
      [{ name: "Page", path: "/app/pages/demos/exceptions/+page.haml" }],
    );

    const exception = document.querySelector("mayu-exception");
    expect(exception).not.toBeNull();
    expect(exception?.textContent).toContain("NoMatchingPatternError");
    expect(exception?.textContent).toContain("The callback failed");
    expect(exception?.textContent).toContain("%Page");
  });

  it("highlights the source line named by a module id backtrace frame", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    await renderError(
      "app:/CustomElement.tsx",
      "SyntaxError",
      "Expected an element",
      ["app:/CustomElement.tsx:2:24", "app:/other.tsx:9"],
      "const a = 1;\nconst b = 2;\nconst c = 3;\n",
      [],
    );

    const lines = document.querySelectorAll("mayu-exception li.source-line");
    const highlighted = document.querySelectorAll(
      "mayu-exception li.source-line.is-interesting",
    );

    expect(lines).toHaveLength(3);
    expect(highlighted).toHaveLength(1);
    expect(highlighted[0]?.textContent).toContain("const b = 2;");
  });

  it("highlights the line a build error reports without a backtrace", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    await renderError(
      "app:/CustomElement.tsx",
      "Module not found",
      'Could not resolve "./colors.toml"',
      [],
      'import a from "./a";\nimport colors from "./colors.toml";\n',
      [],
      2,
      21,
      ["Did you mean ./colors.json?"],
    );

    const highlighted = document.querySelectorAll(
      "mayu-exception li.source-line.is-interesting",
    );

    expect(highlighted).toHaveLength(1);
    expect(highlighted[0]?.textContent).toContain("./colors.toml");

    const caret = document.querySelector("mayu-exception li.source-caret");
    expect(caret).not.toBeNull();
    // Gutter is one digit wide plus two spaces, then column 21.
    expect(caret?.textContent).toBe(" ".repeat(1 + 2 + 20) + "^");

    const hints = document.querySelectorAll("mayu-exception li.hint-item");
    expect(hints).toHaveLength(1);
    expect(hints[0]?.textContent).toContain("./colors.json");
  });

  it("hides panels that have no content", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    await import("./custom-elements/mayu-exception");

    await renderError(
      "app:/broken.haml",
      "Haml parse error",
      'Invalid tag: "%@$O".',
      [],
      "%article\n  %@$O\n",
      [],
      2,
      null,
      [],
    );

    const root = document.querySelector("mayu-exception")?.shadowRoot;
    const hidden = (name: string) =>
      root?.querySelector(`slot[name="${name}"]`)?.closest("section")?.hidden;

    expect(hidden("backtrace")).toBe(true);
    expect(hidden("tree-path")).toBe(true);
    expect(hidden("hints")).toBe(true);
    expect(hidden("source")).toBe(false);
  });
});

describe("renderError backtrace", () => {
  afterEach(() => {
    document.body.innerHTML = "";
    vi.restoreAllMocks();
  });

  it("highlights the frames of the module and dims the ones through Mayu", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    await import("./custom-elements/mayu-exception");

    await renderError(
      "app:/pages/+page.haml",
      "RuntimeError",
      "boom",
      [
        "app:/pages/+page.haml:2:in 'render'",
        "mayu-live/lib/mayu/runtime/vnodes/vcomponent.rb:1:in 'update'",
      ],
      "%p hello\n= raise\n",
      [],
      2,
      null,
      [],
    );

    const element = document.querySelector("mayu-exception")!;
    const items = [...element.querySelectorAll(".trace-item")];
    expect(items[0].classList.contains("is-interesting")).toBe(true);
    expect(items[1].classList.contains("is-framework")).toBe(true);
    expect(
      element.querySelector(".source-line.is-interesting")?.textContent,
    ).toContain("= raise");
  });

  it("hides frames through Mayu until the checkbox asks for them", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    await import("./custom-elements/mayu-exception");

    await renderError(
      "app:/pages/+page.haml",
      "RuntimeError",
      "boom",
      [
        "app:/pages/+page.haml:2:in 'render'",
        "mayu-live/lib/mayu/runtime/vnodes/vcomponent.rb:1:in 'update'",
        "<internal:kernel>:187:in 'Kernel#loop'",
      ],
      null,
      [],
      null,
      null,
      [],
    );

    const element = document.querySelector("mayu-exception")!;
    const root = element.shadowRoot!;
    const label = root.querySelector<HTMLElement>("[data-framework-toggle]")!;
    const checkbox = root.querySelector<HTMLInputElement>(
      "[data-action='toggle-framework-frames']",
    )!;

    expect(label.hidden).toBe(false);
    expect(root.querySelector("[data-framework-count]")?.textContent).toBe(
      "Show 2 more frames through Mayu",
    );
    expect(element.hasAttribute("show-framework-frames")).toBe(false);

    checkbox.checked = true;
    checkbox.dispatchEvent(new Event("change"));

    expect(element.hasAttribute("show-framework-frames")).toBe(true);
  });
});
