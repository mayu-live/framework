import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("./ping", () => ({ updatePing: vi.fn() }));

import Runtime from "./runtime";

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

    await runtime.apply([
      ["Initialize", tree()],
      ["SetListener", "button", "click", "first"],
    ]);
    button.dispatchEvent(new MouseEvent("click"));
    expect(onEvent).toHaveBeenLastCalledWith(expect.any(MouseEvent), "first");

    await runtime.apply([
      ["SetListener", "button", "click", "second"],
      ["RemoveListener", "button", "click", "first"],
    ]);
    button.dispatchEvent(new MouseEvent("click"));
    expect(onEvent).toHaveBeenLastCalledWith(expect.any(MouseEvent), "second");

    await runtime.apply([["RemoveListener", "button", "click", "second"]]);
    button.dispatchEvent(new MouseEvent("click"));
    expect(onEvent).toHaveBeenCalledTimes(2);
  });

  it("clears listeners before applying a reconnect bootstrap", async () => {
    document.body.innerHTML = "<button>Go</button>";
    const onEvent = vi.fn();
    const runtime = new Runtime(onEvent);
    const button = document.querySelector("button")!;

    await runtime.apply([
      ["Initialize", tree()],
      ["SetListener", "button", "click", "listener"],
      ["Initialize", tree()],
      ["SetListener", "button", "click", "listener"],
    ]);
    button.dispatchEvent(new MouseEvent("click"));

    expect(onEvent).toHaveBeenCalledTimes(1);
  });
});
