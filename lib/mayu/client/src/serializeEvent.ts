function serializeObject(obj: any) {
  switch (typeof obj) {
    case "function":
      return undefined;
    case "string":
    case "number":
    case "boolean":
      return obj;
  }

  if (obj === null) return null;

  if (obj instanceof HTMLSelectElement) {
    return {
      tagName: obj.tagName,
      id: obj.id,
      type: obj.type,
      name: obj.name,
      value: obj.value,
    };
  }

  if (obj instanceof HTMLInputElement) {
    return {
      tagName: obj.tagName,
      id: obj.id,
      type: obj.type,
      name: obj.name,
      value: obj.value,
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

  if (obj instanceof Window) {
    return { type: "window" };
  }

  if (obj instanceof Element) {
    return {
      tagName: obj.tagName,
      id: obj.id,
    };
  }

  if (typeof obj === "object") {
    const res: Record<string, any> = {};

    for (const property in obj) {
      const value = obj[property];

      if (typeof value === "object") continue;

      const serialized = serializeObject(value);

      if (serialized !== undefined) {
        res[property] = serialized;
      }
    }
    return res;
  }

  return undefined;
}

function serializeEvent(e: Event) {
  const payload: Record<string, any> = {};

  for (const property in e) {
    const serialized = serializeObject((e as any)[property]);

    if (serialized !== undefined) {
      payload[property] = serialized;
    }
  }

  if (e.target instanceof HTMLFormElement) {
    payload.formData = Object.fromEntries(new FormData(e.target).entries());

    if (
      e instanceof SubmitEvent &&
      e.submitter instanceof HTMLButtonElement &&
      e.submitter.name
    ) {
      // If the submit event was triggered by clicking a submit button,
      // then we will include it's value in the form data..
      payload.formData[e.submitter.name] = e.submitter.value;
    }
  }

  return payload;
}

export default serializeEvent;
