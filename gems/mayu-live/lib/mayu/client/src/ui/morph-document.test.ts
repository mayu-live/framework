import { afterEach, describe, expect, it } from "vitest";

import morphDocument from "./morph-document";

function page(body: string) {
  return `<!DOCTYPE html>\n<html><head></head><body>${body}</body></html>`;
}

describe("morphDocument", () => {
  afterEach(() => {
    document.body.replaceChildren();
  });

  // Patches set the property and never the attribute, so the attribute in
  // the server's page is the only place the state is written down.
  it("gives a checkbox the indeterminate state of the server's page", () => {
    document.body.innerHTML = `<input type="checkbox" id="a"><input type="checkbox" id="b">`;
    const [a, b] = document.querySelectorAll("input");
    b.indeterminate = true;

    morphDocument(
      page(
        `<input type="checkbox" id="a" indeterminate><input type="checkbox" id="b">`,
      ),
    );

    expect(document.querySelectorAll("input")).toEqual(
      expect.objectContaining({ 0: a, 1: b }),
    );
    expect(a.indeterminate).toBe(true);
    expect(b.indeterminate).toBe(false);
  });
});
