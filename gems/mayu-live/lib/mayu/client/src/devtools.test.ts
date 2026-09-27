import { afterEach, describe, expect, it, vi } from "vitest";

import Devtools, { type DevtoolsApi } from "./devtools";

describe("Devtools", () => {
  afterEach(() => {
    delete window.__MAYU_DEVTOOLS_HOOK__;
  });

  it("does nothing without a hook", () => {
    const devtools = new Devtools();

    expect(() =>
      devtools.register(
        { node: vi.fn(), nodeId: vi.fn() },
        { inspect: vi.fn() },
      ),
    ).not.toThrow();
  });

  it("registers the runtime and inspector with the hook", async () => {
    let api!: DevtoolsApi;
    window.__MAYU_DEVTOOLS_HOOK__ = {
      register: (registered) => (api = registered),
    };
    const node = document.createElement("div");
    const runtime = {
      node: vi.fn((id: string) => (id === "v1" ? node : undefined)),
      nodeId: vi.fn((target: Node) => (target === node ? "v1" : undefined)),
    };
    const mayu = { inspect: vi.fn(async () => ({ type: "tree" })) };

    new Devtools().register(runtime, mayu);

    expect(api.version).toBe(1);
    expect(api.node("v1")).toBe(node);
    expect(api.nodeId(node)).toBe("v1");
    await expect(api.inspect({ type: "tree" })).resolves.toEqual({
      type: "tree",
    });
    expect(mayu.inspect).toHaveBeenCalledWith({ type: "tree" });
  });

  it("reports applied batches, except those that don't change the page", () => {
    let api!: DevtoolsApi;
    window.__MAYU_DEVTOOLS_HOOK__ = {
      register: (registered) => (api = registered),
    };
    const devtools = new Devtools();
    devtools.register({ node: vi.fn(), nodeId: vi.fn() }, { inspect: vi.fn() });
    const listener = vi.fn();
    const unsubscribe = api.onBatch(listener);

    devtools.batchApplied([["InspectResult", "1", null]]);
    devtools.batchApplied([
      ["Pong", 1],
      ["InspectResult", "2", null],
    ]);
    devtools.batchApplied([["SetTextContent", "v1", "hi"]]);
    unsubscribe();
    devtools.batchApplied([["SetTextContent", "v1", "bye"]]);

    expect(listener).toHaveBeenCalledTimes(1);
    expect(listener).toHaveBeenCalledWith([["SetTextContent", "v1", "hi"]]);
  });
});
