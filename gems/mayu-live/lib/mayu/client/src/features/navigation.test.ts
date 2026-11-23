import { afterEach, describe, expect, it, vi } from "vitest";

import TestClient, { FakeNavigation, navigationEvent } from "./test-client";

describe("navigation", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it("intercepts same-origin navigations and sends their path and query", async () => {
    const navigation = new FakeNavigation();
    vi.stubGlobal("navigation", navigation);
    const write = vi.fn(async () => undefined);
    const mayu = new TestClient({ autoPing: false });
    mayu.setWriter({ write } as any);
    const event = navigationEvent();

    navigation.dispatchEvent(event);
    const intercept = event.intercept as ReturnType<typeof vi.fn>;
    expect(intercept).toHaveBeenCalledTimes(1);
    const handled = intercept.mock.calls[0][0].handler();
    let completed = false;
    void handled.then(() => {
      completed = true;
    });
    await Promise.resolve();
    expect(completed).toBe(false);
    mayu.completeNavigation("1");
    await handled;
    expect(completed).toBe(true);

    expect(write).toHaveBeenCalledWith([
      "Navigate",
      expect.any(Number),
      null,
      "1",
      "/next?tab=details",
    ]);
    mayu.dispose();
  });

  it("rejects a pending navigation when the server reports failure", async () => {
    const navigation = new FakeNavigation();
    vi.stubGlobal("navigation", navigation);
    const mayu = new TestClient({ autoPing: false });
    mayu.setWriter({ write: vi.fn(async () => undefined) } as any);
    const event = navigationEvent();

    navigation.dispatchEvent(event);
    const handled = (
      event.intercept as ReturnType<typeof vi.fn>
    ).mock.calls[0][0].handler();
    await Promise.resolve();
    mayu.failNavigation("1");

    await expect(handled).rejects.toThrow("Navigation failed");
    mayu.dispose();
  });

  it("rejects a pending navigation when the browser aborts it", async () => {
    const navigation = new FakeNavigation();
    vi.stubGlobal("navigation", navigation);
    const mayu = new TestClient({ autoPing: false });
    mayu.setWriter({ write: vi.fn(async () => undefined) } as any);
    const abortController = new AbortController();
    const event = navigationEvent({ signal: abortController.signal });

    navigation.dispatchEvent(event);
    const handled = (
      event.intercept as ReturnType<typeof vi.fn>
    ).mock.calls[0][0].handler();
    await Promise.resolve();
    abortController.abort();

    await expect(handled).rejects.toThrow("Navigation aborted");
    mayu.dispose();
  });

  it.each([
    ["a hash change", { hashChange: true }],
    ["a download", { downloadRequest: "file" }],
    ["a form submission", { formData: new FormData() }],
    ["a reload", { navigationType: "reload" }],
    [
      "a cross-origin destination",
      { destination: { url: "https://example.com/next" } },
    ],
  ])("does not intercept %s", (_name, overrides) => {
    const navigation = new FakeNavigation();
    vi.stubGlobal("navigation", navigation);
    const mayu = new TestClient({ autoPing: false });
    mayu.setWriter({ write: vi.fn(async () => undefined) } as any);
    const event = navigationEvent(overrides);

    navigation.dispatchEvent(event);

    expect(event.intercept).not.toHaveBeenCalled();
    mayu.dispose();
  });

  it("uses the native Navigation API for programmatic navigation", () => {
    const navigation = new FakeNavigation();
    vi.stubGlobal("navigation", navigation);
    const mayu = new TestClient({ autoPing: false });

    mayu.navigate("/next");
    mayu.navigate("/current", false);

    expect(navigation.navigate).toHaveBeenNthCalledWith(1, "/next", {
      history: "push",
      info: "mayu:browser-action",
    });
    expect(navigation.navigate).toHaveBeenNthCalledWith(2, "/current", {
      history: "replace",
      info: "mayu:browser-action",
    });
    mayu.dispose();
  });

  it("keeps focus and scroll when a programmatic navigation only changes the query", () => {
    const navigation = new FakeNavigation();
    vi.stubGlobal("navigation", navigation);
    const mayu = new TestClient({ autoPing: false });
    mayu.setWriter({ write: vi.fn(async () => undefined) } as any);
    const event = navigationEvent({
      destination: { url: new URL("?q=char", location.href).href },
      info: "mayu:browser-action",
    });

    navigation.dispatchEvent(event);

    expect(event.intercept).toHaveBeenCalledWith(
      expect.objectContaining({ focusReset: "manual", scroll: "manual" }),
    );
    mayu.completeNavigation("1");
    mayu.dispose();
  });

  it.each([
    [
      "a link to the same path",
      { destination: { url: new URL("?q=char", location.href).href } },
    ],
    [
      "a programmatic navigation to another path",
      { info: "mayu:browser-action" },
    ],
  ])("resets focus and scroll after %s", (_name, overrides) => {
    const navigation = new FakeNavigation();
    vi.stubGlobal("navigation", navigation);
    const mayu = new TestClient({ autoPing: false });
    mayu.setWriter({ write: vi.fn(async () => undefined) } as any);
    const event = navigationEvent(overrides);

    navigation.dispatchEvent(event);

    const options = (event.intercept as ReturnType<typeof vi.fn>).mock
      .calls[0][0];
    expect(options).not.toHaveProperty("focusReset");
    expect(options).not.toHaveProperty("scroll");
    mayu.completeNavigation("1");
    mayu.dispose();
  });
});

describe("document navigation", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it.each(["a", "form", "button", "input"])(
    "bypasses interception for a marked %s",
    (tag) => {
      const navigation = new FakeNavigation();
      vi.stubGlobal("navigation", navigation);
      const mayu = new TestClient({ autoPing: false });
      mayu.setWriter({ write: vi.fn(async () => undefined) } as any);
      const source = document.createElement(tag);
      source.setAttribute("data-mayu-navigation", "document");
      const event = navigationEvent({ sourceElement: source });
      navigation.dispatchEvent(event);
      expect(event.intercept).not.toHaveBeenCalled();
      mayu.dispose();
    },
  );

  it("lets a submitter override its form's navigation mode", () => {
    const navigation = new FakeNavigation();
    vi.stubGlobal("navigation", navigation);
    const mayu = new TestClient({ autoPing: false });
    mayu.setWriter({ write: vi.fn(async () => undefined) } as any);
    const form = document.createElement("form");
    form.setAttribute("data-mayu-navigation", "document");
    const button = document.createElement("button");
    form.append(button);
    const native = navigationEvent({ sourceElement: button });
    navigation.dispatchEvent(native);
    expect(native.intercept).not.toHaveBeenCalled();
    button.setAttribute("data-mayu-navigation", "live");
    const live = navigationEvent({ sourceElement: button });
    navigation.dispatchEvent(live);
    expect(live.intercept).toHaveBeenCalled();
    mayu.completeNavigation("1");
    mayu.dispose();
  });

  it("uses assign or replace for programmatic document navigation", () => {
    const assign = vi.fn();
    const replace = vi.fn();
    vi.stubGlobal("location", { assign, replace, href: "http://localhost/" });
    const mayu = new TestClient({ autoPing: false });
    mayu.navigate("/handler?q=1", true, true);
    mayu.navigate("/handler?q=2", false, true);
    expect(assign).toHaveBeenCalledWith("/handler?q=1");
    expect(replace).toHaveBeenCalledWith("/handler?q=2");
    mayu.dispose();
  });

  it("forces a document request on the current resource without reloading earlier entries", () => {
    const replaceLocation = vi.fn();
    vi.stubGlobal("location", {
      href: "http://localhost/handler?q=1#part",
      origin: "http://localhost",
      pathname: "/handler",
      search: "?q=1",
      replace: replaceLocation,
    });
    const replace = vi
      .spyOn(history, "replaceState")
      .mockImplementation(() => undefined);
    const push = vi
      .spyOn(history, "pushState")
      .mockImplementation(() => undefined);
    const mayu = new TestClient({ autoPing: false });
    mayu.navigate("/handler?q=1#part", false, true);
    expect(replace).toHaveBeenCalledWith(
      history.state,
      "",
      "http://localhost/handler?q=1&__mayu_document_navigation=#part",
    );
    expect(replaceLocation).toHaveBeenLastCalledWith(
      "http://localhost/handler?q=1#part",
    );
    mayu.navigate("#other", true, true);
    expect(push).toHaveBeenCalledWith(
      history.state,
      "",
      "http://localhost/handler?q=1&__mayu_document_navigation=#other",
    );
    expect(replaceLocation).toHaveBeenLastCalledWith(
      "http://localhost/handler?q=1#other",
    );
    mayu.dispose();
  });

  it("does not intercept the Navigation API event raised by location.replace", () => {
    const navigation = new FakeNavigation();
    vi.stubGlobal("navigation", navigation);
    const origin = location.origin;
    const destination = new URL("/handler", location.href).href;
    const event = navigationEvent({ destination: { url: destination } });
    const replace = vi.fn(() => navigation.dispatchEvent(event));
    vi.stubGlobal("location", { href: origin + "/", origin, replace });
    const mayu = new TestClient({ autoPing: false });
    mayu.setWriter({ write: vi.fn(async () => undefined) } as any);
    mayu.navigate(destination, false, true);
    expect(replace).toHaveBeenCalledWith(destination);
    expect(event.intercept).not.toHaveBeenCalled();
    const subsequent = navigationEvent({ destination: { url: destination } });
    navigation.dispatchEvent(subsequent);
    expect(subsequent.intercept).toHaveBeenCalled();
    mayu.completeNavigation("1");
    mayu.dispose();
  });

  it("waits for history commitment before replacing a handler-only destination", async () => {
    let finish!: () => void;
    const finished = new Promise<void>((resolve) => {
      finish = resolve;
    });
    const navigation = Object.assign(new FakeNavigation(), {
      transition: { finished },
    });
    vi.stubGlobal("navigation", navigation);
    const mayu = new TestClient({ autoPing: false });
    mayu.setWriter({ write: vi.fn(async () => undefined) } as any);
    const navigate = vi
      .spyOn(mayu.navigation, "navigate")
      .mockImplementation(() => undefined);
    const destination = new URL("/handler?q=1#section", location.origin).href;
    const event = navigationEvent({ destination: { url: destination } });
    navigation.dispatchEvent(event);
    const handled = (
      event.intercept as ReturnType<typeof vi.fn>
    ).mock.calls[0][0].handler();
    mayu.documentNavigation("stale", "/other");
    mayu.documentNavigation("1", "/handler?q=1");
    await handled;
    expect(navigate).not.toHaveBeenCalled();
    finish();
    await finished;
    expect(navigate).toHaveBeenCalledWith(destination, false, true);
    mayu.dispose();
  });
});
