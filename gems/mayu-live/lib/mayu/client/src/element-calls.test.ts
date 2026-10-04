import { afterEach, describe, expect, it, vi } from "vitest";

import { callElementMethod, ELEMENT_METHODS } from "./element-calls";

describe("element calls", () => {
  afterEach(() => {
    document.body.innerHTML = "";
    vi.restoreAllMocks();
  });

  it("calls the camelCase method with the arguments", () => {
    const input = document.createElement("input");
    const focus = vi.spyOn(input, "focus");
    const setSelectionRange = vi.spyOn(input, "setSelectionRange");

    callElementMethod(input, "focus", [{ preventScroll: true }]);
    callElementMethod(input, "set_selection_range", [1, 3]);

    expect(focus).toHaveBeenCalledWith({ preventScroll: true });
    expect(setSelectionRange).toHaveBeenCalledWith(1, 3);
  });

  it("maps every name to a method of that name in camelCase", () => {
    for (const [name, method] of Object.entries(ELEMENT_METHODS)) {
      expect(method).toBe(
        name.replace(/_([a-z])/g, (_, letter: string) => letter.toUpperCase()),
      );
    }
  });

  it("refuses names outside the table", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const form = document.createElement("form");
    const remove = vi.spyOn(form, "remove");

    for (const name of ["remove", "__proto__", "constructor", "toString"]) {
      callElementMethod(form, name, []);
    }

    expect(remove).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledTimes(4);
  });

  it("reports a missing element instead of throwing", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);

    callElementMethod(undefined, "focus", []);
    callElementMethod(document.createTextNode("text"), "focus", []);

    expect(warn).toHaveBeenCalledTimes(2);
  });

  it("reports a method the element doesn't have", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);

    callElementMethod(document.createElement("div"), "reset", []);

    expect(warn).toHaveBeenCalledWith("Can't call reset on <div>");
  });

  it("reports a method that throws", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const dialog = document.createElement("dialog");
    dialog.showModal = () => {
      throw new DOMException("Already open", "InvalidStateError");
    };

    expect(() => callElementMethod(dialog, "show_modal", [])).not.toThrow();
    expect(warn).toHaveBeenCalledOnce();
  });
});
