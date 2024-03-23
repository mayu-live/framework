// Copyright Andreas Alin <andreas.alin@gmail.com>
// License: AGPL-3.0

export default function serializeEvent(e: Event) {
  const payload: Record<string, any> = {};

  payload.type = e.constructor.name;

  if (e.currentTarget) {
    payload.currentTarget = serializeElement(e.currentTarget as Element);
  }

  if (e.target) {
    payload.target = serializeElement(e.target as Element);
  }

  if (e instanceof MouseEvent) {
    payload.buttons = e.buttons;
  }

  if (e instanceof SubmitEvent) {
    if (e.submitter instanceof HTMLElement) {
      payload.submitter = serializeElement(e.submitter);
    }
  }

  return payload;
}

function serializeElement(elem: Element) {
  if (elem instanceof HTMLFormElement) {
    const formData = Object.fromEntries(new FormData(elem).entries());

    return {
      tagName: elem.tagName,
      id: elem.id,
      method: elem.method,
      target: elem.target,
      name: elem.name,
      formData,
    };
  }

  if (elem instanceof HTMLSelectElement) {
    return {
      tagName: elem.tagName,
      id: elem.id,
      type: elem.type,
      name: elem.name,
      value: elem.value,
    };
  }

  if (elem instanceof HTMLDetailsElement) {
    return {
      tagName: elem.tagName,
      id: elem.id,
      open: elem.open,
    };
  }

  if (elem instanceof HTMLInputElement) {
    return {
      tagName: elem.tagName,
      id: elem.id,
      type: elem.type,
      name: elem.name,
      value: elem.value,
      checked: elem.checked,
    };
  }

  if (elem instanceof HTMLButtonElement) {
    return {
      tagName: elem.tagName,
      id: elem.id,
      type: elem.type,
      name: elem.name,
      value: elem.value,
    };
  }

  if (elem instanceof HTMLElement) {
    return {
      tagName: elem.tagName,
      id: elem.id,
    };
  }

  return {};
}
