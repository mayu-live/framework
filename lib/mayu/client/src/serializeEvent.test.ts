import { afterEach, describe, expect, it } from "vitest";

import serializeEvent from "./serializeEvent";

function captureSerializedEvent(target: Element, type: string, event: Event) {
  let payload: Record<string, any> | undefined;

  target.addEventListener(type, (e) => {
    payload = serializeEvent(e);
  });

  target.dispatchEvent(event);

  if (!payload) throw new Error("Expected serialized payload");
  return payload as Record<string, any>;
}

describe("serializeEvent", () => {
  afterEach(() => {
    document.body.innerHTML = "";
  });

  it("serializes dataset for html and svg elements", () => {
    const button = document.createElement("button");
    button.id = "save-button";
    button.dataset.action = "save";
    document.body.append(button);

    const htmlPayload = captureSerializedEvent(
      button,
      "click",
      new MouseEvent("click", {
        bubbles: true,
        cancelable: true,
        button: 0,
        buttons: 1,
      })
    );

    expect(htmlPayload.currentTarget.dataset).toEqual({ action: "save" });
    expect(htmlPayload.target.dataset).toEqual({ action: "save" });

    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    const circle = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "circle"
    );
    circle.dataset.state = "active";
    svg.append(circle);
    document.body.append(svg);

    const svgPayload = captureSerializedEvent(
      circle,
      "click",
      new MouseEvent("click", { bubbles: true, cancelable: true })
    );

    expect(svgPayload.currentTarget.dataset).toEqual({ state: "active" });
    expect(svgPayload.target.dataset).toEqual({ state: "active" });
  });

  it("serializes keyboard event metadata", () => {
    const input = document.createElement("input");
    document.body.append(input);

    const payload = captureSerializedEvent(
      input,
      "keydown",
      new KeyboardEvent("keydown", {
        bubbles: true,
        cancelable: true,
        key: "A",
        code: "KeyA",
        location: 1,
        repeat: true,
        ctrlKey: true,
        shiftKey: true,
      })
    );

    expect(payload.type).toBe("KeyboardEvent");
    expect(payload.eventType).toBe("keydown");
    expect(payload.key).toBe("A");
    expect(payload.code).toBe("KeyA");
    expect(payload.location).toBe(1);
    expect(payload.repeat).toBe(true);
    expect(payload.ctrlKey).toBe(true);
    expect(payload.shiftKey).toBe(true);
  });

  it("serializes textarea values", () => {
    const textarea = document.createElement("textarea");
    textarea.name = "message";
    textarea.value = "hello world";
    textarea.selectionStart = 2;
    textarea.selectionEnd = 5;
    document.body.append(textarea);

    const payload = captureSerializedEvent(
      textarea,
      "input",
      new Event("input", { bubbles: true, cancelable: true })
    );

    expect(payload.target).toMatchObject({
      tagName: "TEXTAREA",
      name: "message",
      value: "hello world",
      selectionStart: 2,
      selectionEnd: 5,
    });
  });

  it("serializes select metadata for multi-select controls", () => {
    const select = document.createElement("select");
    select.name = "flavor";
    select.multiple = true;

    const vanilla = document.createElement("option");
    vanilla.value = "vanilla";
    vanilla.selected = true;
    const chocolate = document.createElement("option");
    chocolate.value = "chocolate";
    chocolate.selected = true;
    select.append(vanilla, chocolate);
    document.body.append(select);

    const payload = captureSerializedEvent(
      select,
      "change",
      new Event("change", { bubbles: true, cancelable: true })
    );

    expect(payload.target).toMatchObject({
      tagName: "SELECT",
      name: "flavor",
      multiple: true,
      selectedOptions: ["vanilla", "chocolate"],
      value: "vanilla",
      selectedIndex: 0,
    });
  });

  it("serializes submit details and grouped formData values", () => {
    const form = document.createElement("form");
    form.name = "save-form";
    form.method = "post";

    const firstTag = document.createElement("input");
    firstTag.name = "tag";
    firstTag.value = "frontend";

    const secondTag = document.createElement("input");
    secondTag.name = "tag";
    secondTag.value = "ruby";

    const submitButton = document.createElement("button");
    submitButton.type = "submit";
    submitButton.name = "action";
    submitButton.value = "save";

    form.append(firstTag, secondTag, submitButton);
    document.body.append(form);

    const payload = captureSerializedEvent(
      form,
      "submit",
      new SubmitEvent("submit", {
        bubbles: true,
        cancelable: true,
        submitter: submitButton,
      })
    );

    expect(payload.target.formData.tag).toEqual(["frontend", "ruby"]);
    expect(payload.submitter).toMatchObject({
      tagName: "BUTTON",
      name: "action",
      value: "save",
    });
  });
});
