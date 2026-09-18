import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("./ping", () => ({ updatePing: vi.fn() }));

import Runtime from "./runtime";
import { updatePing } from "./ping";

function tree() {
  return {
    id: "document",
    name: "#document",
    children: [
      {
        id: "html",
        name: "HTML",
        children: [
          { id: "head", name: "HEAD", children: [] },
          {
            id: "body",
            name: "BODY",
            children: [{ id: "button", name: "BUTTON", children: [] }],
          },
        ],
      },
    ],
  };
}

describe("runtime listeners", () => {
  afterEach(() => {
    document.documentElement.innerHTML = "<head></head><body></body>";
    vi.restoreAllMocks();
  });

  it("installs, replaces, and removes listeners by listener id", async () => {
    document.body.innerHTML = "<button>Go</button>";
    const onEvent = vi.fn();
    const runtime = new Runtime(onEvent);
    const button = document.querySelector("button")!;

    await runtime.applyBatch([
      ["Initialize", tree()],
      ["SetListener", "button", "click", "first"],
    ]);
    button.dispatchEvent(new MouseEvent("click"));
    expect(onEvent).toHaveBeenLastCalledWith(expect.any(MouseEvent), "first");

    await runtime.applyBatch([
      ["SetListener", "button", "click", "second"],
      ["RemoveListener", "button", "click", "first"],
    ]);
    button.dispatchEvent(new MouseEvent("click"));
    expect(onEvent).toHaveBeenLastCalledWith(expect.any(MouseEvent), "second");

    await runtime.applyBatch([["RemoveListener", "button", "click", "second"]]);
    button.dispatchEvent(new MouseEvent("click"));
    expect(onEvent).toHaveBeenCalledTimes(2);
  });

  it("clears listeners before applying a reconnect bootstrap", async () => {
    document.body.innerHTML = "<button>Go</button>";
    const onEvent = vi.fn();
    const runtime = new Runtime(onEvent);
    const button = document.querySelector("button")!;

    await runtime.applyBatch([
      ["Initialize", tree()],
      ["SetListener", "button", "click", "listener"],
      ["Initialize", tree()],
      ["SetListener", "button", "click", "listener"],
    ]);
    button.dispatchEvent(new MouseEvent("click"));

    expect(onEvent).toHaveBeenCalledTimes(1);
  });
});

describe("runtime view transitions", () => {
  afterEach(() => {
    delete (document as unknown as { startViewTransition?: unknown })
      .startViewTransition;
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it("passes transition types to the View Transitions API", async () => {
    const startViewTransition = vi.fn(
      (options: { update: () => void; types: string[] }) => {
        options.update();
        return { updateCallbackDone: Promise.resolve() };
      },
    );
    (
      document as unknown as { startViewTransition?: unknown }
    ).startViewTransition = startViewTransition;
    vi.stubGlobal("CSS", { supports: () => true });

    const runtime = new Runtime(vi.fn());
    await runtime.applyBatch([["ViewTransition", [], ["reorder"]]]);

    expect(startViewTransition).toHaveBeenCalledWith(
      expect.objectContaining({ types: ["reorder"] }),
    );
  });

  it("uses an element scope when one is provided", async () => {
    const startViewTransition = vi.fn((update: () => void) => {
      update();
      return { updateCallbackDone: Promise.resolve() };
    });
    document.body.innerHTML = '<div id="reordering-grid"></div>';
    const scope = document.getElementById("reordering-grid") as HTMLElement & {
      startViewTransition?: unknown;
    };
    scope.startViewTransition = startViewTransition;

    const runtime = new Runtime(vi.fn());
    await runtime.applyBatch([["ViewTransition", [], [], "reordering-grid"]]);

    expect(startViewTransition).toHaveBeenCalledOnce();
  });

  it("waits for a transition animation to finish before completing the batch", async () => {
    let finish!: () => void;
    const finished = new Promise<void>((resolve) => {
      finish = resolve;
    });
    const startViewTransition = vi.fn((update: () => void) => {
      update();
      return {
        updateCallbackDone: Promise.resolve(),
        finished,
      };
    });
    (
      document as unknown as { startViewTransition?: unknown }
    ).startViewTransition = startViewTransition;

    const runtime = new Runtime(vi.fn());
    const applying = runtime.applyBatch([["ViewTransition", []]]);
    let completed = false;
    void applying.then(() => {
      completed = true;
    });

    await Promise.resolve();
    expect(completed).toBe(false);

    finish();
    await applying;
    expect(completed).toBe(true);
  });
});

describe("runtime autofocus", () => {
  beforeEach(() => {
    // jsdom has no requestIdleCallback; run the callback right away.
    vi.stubGlobal("requestIdleCallback", (callback: () => void) => callback());
  });

  afterEach(() => {
    document.documentElement.innerHTML = "<head></head><body></body>";
    vi.unstubAllGlobals();
  });

  it("focuses a textarea with autofocus after its parent is re-rendered", async () => {
    document.body.innerHTML =
      "<form><input name=other><textarea autofocus name=message></textarea></form>";
    const runtime = new Runtime(vi.fn());
    const textarea = document.querySelector("textarea")!;

    await runtime.applyBatch([
      [
        "Initialize",
        {
          id: "document",
          name: "#document",
          children: [
            {
              id: "html",
              name: "HTML",
              children: [
                { id: "head", name: "HEAD", children: [] },
                {
                  id: "body",
                  name: "BODY",
                  children: [
                    {
                      id: "form",
                      name: "FORM",
                      children: [
                        { id: "other", name: "INPUT", children: [] },
                        { id: "textarea", name: "TEXTAREA", children: [] },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
      ["ReplaceChildren", "form", ["other", "textarea"]],
    ]);

    expect(document.activeElement).toBe(textarea);
  });
});

describe("runtime ReplaceChildren", () => {
  const moveBeforeDescriptor = Object.getOwnPropertyDescriptor(
    Element.prototype,
    "moveBefore",
  );

  function listTree() {
    return {
      id: "document",
      name: "#document",
      children: [
        {
          id: "html",
          name: "HTML",
          children: [
            { id: "head", name: "HEAD", children: [] },
            {
              id: "body",
              name: "BODY",
              children: [
                {
                  id: "list",
                  name: "DIV",
                  children: [
                    { id: "first", name: "SPAN", children: [] },
                    { id: "second", name: "SPAN", children: [] },
                  ],
                },
              ],
            },
          ],
        },
      ],
    };
  }

  beforeEach(() => {
    vi.stubGlobal("requestIdleCallback", (callback: () => void) => callback());
    document.body.innerHTML =
      "<div><span>first</span><span>second</span></div>";
  });

  afterEach(() => {
    if (moveBeforeDescriptor) {
      Object.defineProperty(
        Element.prototype,
        "moveBefore",
        moveBeforeDescriptor,
      );
    } else {
      delete (Element.prototype as { moveBefore?: unknown }).moveBefore;
    }
    document.documentElement.innerHTML = "<head></head><body></body>";
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it("reorders retained children with moveBefore", async () => {
    const moveBefore = vi.fn(function (
      this: Element,
      node: Node,
      before: Node | null,
    ) {
      this.insertBefore(node, before);
    });
    Object.defineProperty(Element.prototype, "moveBefore", {
      configurable: true,
      value: moveBefore,
    });

    const runtime = new Runtime(vi.fn());
    const list = document.body.firstElementChild!;
    const replaceChildren = vi.spyOn(list, "replaceChildren");

    await runtime.applyBatch([
      ["Initialize", listTree()],
      ["ReplaceChildren", "list", ["second", "first"]],
    ]);

    expect([...list.children].map((child) => child.textContent)).toEqual([
      "second",
      "first",
    ]);
    expect(moveBefore).toHaveBeenCalledWith(list.children[0], list.children[1]);
    expect(replaceChildren).not.toHaveBeenCalled();
  });

  it("falls back to replaceChildren without moveBefore", async () => {
    delete (Element.prototype as { moveBefore?: unknown }).moveBefore;

    const runtime = new Runtime(vi.fn());
    const list = document.body.firstElementChild!;
    const replaceChildren = vi.spyOn(list, "replaceChildren");

    await runtime.applyBatch([
      ["Initialize", listTree()],
      ["ReplaceChildren", "list", ["second", "first"]],
    ]);

    expect([...list.children].map((child) => child.textContent)).toEqual([
      "second",
      "first",
    ]);
    expect(replaceChildren).toHaveBeenCalledOnce();
  });
});

describe("runtime command errors", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("logs and continues by default", async () => {
    const error = vi
      .spyOn(console, "error")
      .mockImplementation(() => undefined);
    const runtime = new Runtime(vi.fn());

    await runtime.applyBatch([["UnknownCommand"], ["Pong", 10]]);

    expect(error).toHaveBeenCalledWith(
      "Command 0 (UnknownCommand) failed",
      expect.any(Error),
    );
    expect(updatePing).toHaveBeenCalledOnce();
  });

  it("throws and stops a strict batch", async () => {
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    const runtime = new Runtime(vi.fn(), { commandErrorPolicy: "throw" });

    await expect(
      runtime.applyBatch([["UnknownCommand"], ["Pong", 10]]),
    ).rejects.toThrow("Unknown command: UnknownCommand");
    expect(updatePing).not.toHaveBeenCalled();
  });
});
