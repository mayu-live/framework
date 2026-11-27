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

  it("keeps what the user entered in fields the server says nothing new about", () => {
    document.body.innerHTML = `
      <input id="text"><input id="preset" value="preset">
      <input type="checkbox" id="box">
      <textarea>draft</textarea>
      <select><option>one</option><option>two</option></select>`;
    const html = page(document.body.innerHTML);
    const [text, preset, box] = document.querySelectorAll("input");
    const textarea = document.querySelector("textarea")!;
    const select = document.querySelector("select")!;
    text.value = "typed";
    preset.value = "changed";
    box.checked = true;
    textarea.value = "longer draft";
    select.selectedIndex = 1;

    morphDocument(html);

    expect(text.value).toBe("typed");
    expect(preset.value).toBe("changed");
    expect(box.checked).toBe(true);
    expect(textarea.value).toBe("longer draft");
    expect(textarea.defaultValue).toBe("draft");
    expect(select.value).toBe("two");
  });

  it("gives a field the server's value when that has changed", () => {
    document.body.innerHTML = `
      <input id="text" value="a">
      <input type="checkbox" id="box">
      <textarea>a</textarea>
      <select><option>one</option><option>two</option><option>three</option></select>`;
    const [text, box] = document.querySelectorAll("input");
    const textarea = document.querySelector("textarea")!;
    const select = document.querySelector("select")!;
    text.value = "typed";
    textarea.value = "typed";
    select.selectedIndex = 1;

    morphDocument(
      page(`
      <input id="text" value="b">
      <input type="checkbox" id="box" checked>
      <textarea>b</textarea>
      <select><option>one</option><option>two</option><option selected>three</option></select>`),
    );

    expect(text.value).toBe("b");
    expect(box.checked).toBe(true);
    expect(textarea.value).toBe("b");
    expect(select.value).toBe("three");
  });
});
