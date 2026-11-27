import { afterEach, describe, expect, it, vi } from "vitest";

import type { RenderErrorInfo } from "./error-report";
import renderError from "./render-error";

function error(overrides: Partial<RenderErrorInfo>): RenderErrorInfo {
  return {
    file: "app:/pages/+page.haml",
    type: "RuntimeError",
    message: "boom",
    backtrace: [],
    source: null,
    treePath: [],
    line: null,
    column: null,
    hints: [],
    ...overrides,
  };
}

// The overlay draws in its shadow root.
function overlay() {
  return document.querySelector("mayu-exception")!.shadowRoot!;
}

function sectionHidden(listId: string) {
  return overlay().getElementById(listId)!.closest("section")!.hidden;
}

describe("renderError", () => {
  afterEach(() => {
    document.body.innerHTML = "";
    vi.restoreAllMocks();
  });

  it("shows the error in a modal dialog and logs it", () => {
    const log = vi.spyOn(console, "error").mockImplementation(() => {});

    renderError(
      error({
        file: "/app/pages/demos/exceptions/+page.haml",
        type: "NoMatchingPatternError",
        message: "The callback failed",
        backtrace: [
          "/app/pages/demos/exceptions/+page.haml:13:in 'handle_click'",
        ],
        treePath: [
          { name: "body" },
          { name: "Page", path: "/app/pages/demos/exceptions/+page.haml" },
        ],
      }),
    );

    const root = overlay();
    expect(root.querySelector("dialog")!.open).toBe(true);
    expect(root.getElementById("type")!.textContent).toBe(
      "NoMatchingPatternError",
    );
    expect(root.getElementById("location")!.textContent).toBe(
      "/app/pages/demos/exceptions/+page.haml",
    );
    expect(root.getElementById("message")!.textContent).toBe(
      "The callback failed",
    );
    expect(
      [...root.querySelectorAll(".tree-item")].map((item) => item.textContent),
    ).toEqual(["%body", "%Page (/app/pages/demos/exceptions/+page.haml)"]);
    expect(log).toHaveBeenCalledOnce();
  });

  it("keeps what it draws out of the page", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    renderError(error({ source: "%p\n", line: 1 }));

    expect(document.querySelector("mayu-exception")!.childNodes).toHaveLength(
      0,
    );
  });

  it("replaces the overlay of an earlier error", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    renderError(error({ message: "first" }));
    renderError(error({ message: "second" }));

    expect(document.querySelectorAll("mayu-exception")).toHaveLength(1);
    expect(overlay().getElementById("message")!.textContent).toBe("second");
  });

  it("goes away when its dialog is closed", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    renderError(error({}));
    overlay().getElementById("close")!.click();

    expect(document.querySelector("mayu-exception")).toBeNull();
  });

  it("highlights the source line named by a backtrace frame", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    renderError(
      error({
        file: "app:/CustomElement.tsx",
        backtrace: ["app:/CustomElement.tsx:2:24", "app:/other.tsx:9"],
        source: "const a = 1;\nconst b = 2;\nconst c = 3;\n",
      }),
    );

    const lines = overlay().querySelectorAll(".source-line");
    const highlighted = overlay().querySelectorAll(
      ".source-line.is-interesting",
    );

    expect(lines).toHaveLength(3);
    expect(highlighted).toHaveLength(1);
    expect(highlighted[0].textContent).toBe("2  const b = 2;");
  });

  it("points at the column a build error reports and shows its hints", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    renderError(
      error({
        file: "app:/CustomElement.tsx",
        type: "Module not found",
        message: 'Could not resolve "./colors.toml"',
        source: 'import a from "./a";\nimport colors from "./colors.toml";\n',
        line: 2,
        column: 21,
        hints: ["Did you mean ./colors.json?"],
      }),
    );

    const items = [...overlay().querySelectorAll("#source li")];
    expect(items.map((item) => item.className)).toEqual([
      "source-line",
      "source-line is-interesting",
      "source-caret",
    ]);
    // Gutter is one digit wide plus two spaces, then column 21.
    expect(items[2].textContent).toBe(" ".repeat(1 + 2 + 20) + "^");

    const hints = overlay().querySelectorAll(".hint-item");
    expect(hints).toHaveLength(1);
    expect(hints[0].textContent).toBe("Did you mean ./colors.json?");
  });

  it("hides the sections that have no content", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    renderError(
      error({
        file: "app:/broken.haml",
        type: "Haml parse error",
        message: 'Invalid tag: "%@$O".',
        source: "%article\n  %@$O\n",
        line: 2,
      }),
    );

    expect(sectionHidden("backtrace")).toBe(true);
    expect(sectionHidden("tree")).toBe(true);
    expect(sectionHidden("hints")).toBe(true);
    expect(sectionHidden("source")).toBe(false);
  });

  it("highlights the frames of the module and dims the ones through Mayu", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    renderError(
      error({
        backtrace: [
          "app:/pages/+page.haml:2:in 'render'",
          "app:/components/Card.haml:4:in 'render'",
          "mayu-live/lib/mayu/runtime/vnodes/vcomponent.rb:1:in 'update'",
        ],
        source: "%p hello\n= raise\n",
        line: 2,
      }),
    );

    const items = [...overlay().querySelectorAll(".trace-item")];
    expect(items.map((item) => item.className)).toEqual([
      "trace-item is-interesting",
      "trace-item",
      "trace-item is-framework",
    ]);
  });

  it("hides frames through Mayu until the checkbox asks for them", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    renderError(
      error({
        backtrace: [
          "app:/pages/+page.haml:2:in 'render'",
          "mayu-live/lib/mayu/runtime/vnodes/vcomponent.rb:1:in 'update'",
          "<internal:kernel>:187:in 'Kernel#loop'",
        ],
      }),
    );

    const root = overlay();
    const backtrace = root.getElementById("backtrace")!;
    const checkbox = root.getElementById(
      "framework-checkbox",
    ) as HTMLInputElement;

    expect(root.getElementById("framework-toggle")!.hidden).toBe(false);
    expect(root.getElementById("framework-count")!.textContent).toBe(
      "Show 2 more frames through Mayu",
    );
    expect(backtrace.classList.contains("show-framework")).toBe(false);

    checkbox.checked = true;
    checkbox.dispatchEvent(new Event("change"));

    expect(backtrace.classList.contains("show-framework")).toBe(true);
  });

  it("offers no checkbox when no frame runs through Mayu", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    renderError(error({ backtrace: ["app:/pages/+page.haml:2:in 'render'"] }));

    expect(overlay().getElementById("framework-toggle")!.hidden).toBe(true);
  });
});
