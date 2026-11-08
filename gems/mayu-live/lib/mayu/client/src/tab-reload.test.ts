import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import TabReloader from "./tab-reload";

class Channel extends EventTarget {
  static instances: Channel[] = [];
  closed = false;

  constructor(public name: string) {
    super();
    Channel.instances.push(this);
  }

  postMessage(data: unknown) {
    for (const other of Channel.instances) {
      if (other !== this && !other.closed && other.name === this.name) {
        other.dispatchEvent(new MessageEvent("message", { data }));
      }
    }
  }

  close() {
    this.closed = true;
  }
}

describe("cross-tab document reload", () => {
  const tabs: TabReloader[] = [];
  const tab = () => {
    const reload = vi.fn();
    const client = new TabReloader(reload);
    tabs.push(client);
    client.start();
    return { client, reload };
  };

  beforeEach(() => {
    Channel.instances = [];
    vi.stubGlobal("BroadcastChannel", Channel);
  });

  afterEach(() => {
    tabs.splice(0).forEach((client) => client.dispose());
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it("automatically listens on the framework channel and excludes the sender", () => {
    const sender = tab();
    const receiver = tab();
    expect(Channel.instances.map((c) => c.name)).toEqual([
      "mayu:browser:v1",
      "mayu:browser:v1",
    ]);
    sender.client.reloadOtherTabs();
    expect(sender.reload).not.toHaveBeenCalled();
    expect(receiver.reload).toHaveBeenCalledOnce();
    // Receiving must not rebroadcast: the sender remains untouched.
    expect(Channel.instances).toHaveLength(2);
  });

  it("reloads hidden tabs immediately and coalesces repeated requests", () => {
    vi.spyOn(document, "visibilityState", "get").mockReturnValue("hidden");
    const sender = tab();
    const receiver = tab();
    sender.client.reloadOtherTabs();
    sender.client.reloadOtherTabs();
    expect(receiver.reload).toHaveBeenCalledOnce();
  });

  it("ignores unrelated messages", () => {
    const receiver = tab();
    const sender = new Channel("mayu:browser:v1");
    [
      null,
      "reload",
      {},
      { type: "identity-changed" },
      { type: "navigate", url: "/elsewhere" },
    ].forEach((data) => sender.postMessage(data));
    expect(receiver.reload).not.toHaveBeenCalled();
    sender.close();
  });

  it("starts only once and reopens after page restoration", () => {
    const receiver = tab();
    receiver.client.start();
    expect(Channel.instances).toHaveLength(1);
    const original = Channel.instances[0];
    window.dispatchEvent(new Event("pagehide"));
    expect(original.closed).toBe(true);
    window.dispatchEvent(new Event("pageshow"));
    expect(Channel.instances).toHaveLength(2);
    expect(Channel.instances[1].closed).toBe(false);
    const sender = new Channel("mayu:browser:v1");
    sender.postMessage({ type: "reload" });
    expect(receiver.reload).toHaveBeenCalledOnce();
    sender.close();
  });

  it("removes lifecycle listeners when disposed", () => {
    const receiver = tab();
    receiver.client.dispose();
    window.dispatchEvent(new Event("pageshow"));
    expect(Channel.instances).toHaveLength(1);
    expect(Channel.instances[0].closed).toBe(true);
  });

  it("does not interfere with startup or actions when channels are unsupported", () => {
    vi.stubGlobal("BroadcastChannel", undefined);
    expect(() => tab().client.reloadOtherTabs()).not.toThrow();
  });

  it("tolerates channel creation and sending failures", () => {
    vi.stubGlobal(
      "BroadcastChannel",
      class {
        constructor() {
          throw new Error("unavailable");
        }
      },
    );
    expect(() => tab().client.reloadOtherTabs()).not.toThrow();
    vi.stubGlobal("BroadcastChannel", Channel);
    const sender = tab();
    vi.spyOn(Channel.instances[0], "postMessage").mockImplementation(() => {
      throw new Error("closed");
    });
    expect(() => sender.client.reloadOtherTabs()).not.toThrow();
  });
});
