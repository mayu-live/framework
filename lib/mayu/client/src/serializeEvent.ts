function serializeElement(obj: any) {
  if (obj instanceof HTMLFormElement) {
    const formData = Object.fromEntries(new FormData(obj).entries());
    return {
      tagName: obj.tagName,
      id: obj.id,
      method: obj.method,
      target: obj.target,
      name: obj.name,
      formData,
    };
  }

  if (obj instanceof HTMLSelectElement) {
    return {
      tagName: obj.tagName,
      id: obj.id,
      type: obj.type,
      name: obj.name,
      value: obj.value,
    };
  }

  if (obj instanceof HTMLDetailsElement) {
    return {
      tagName: obj.tagName,
      id: obj.id,
      open: obj.open,
    };
  }

  if (obj instanceof HTMLInputElement) {
    return {
      tagName: obj.tagName,
      id: obj.id,
      type: obj.type,
      name: obj.name,
      value: obj.value,
      checked: obj.checked,
    };
  }

  if (obj instanceof HTMLButtonElement) {
    return {
      tagName: obj.tagName,
      id: obj.id,
      type: obj.type,
      name: obj.name,
      value: obj.value,
    };
  }

  if (obj instanceof HTMLElement) {
    return {
      tagName: obj.tagName,
      id: obj.id,
    };
  }

  return {};
}

function serializeEvent(e: Event) {
  const payload: Record<string, any> = {};

  payload.type = e.constructor.name;

  if (e.target) {
    payload.target = serializeElement(e.target);
  }

  if (e instanceof SubmitEvent && e.submitter instanceof HTMLElement) {
    payload.submitter = serializeElement(e.submitter);
  }

  return payload;
}

export default serializeEvent;
