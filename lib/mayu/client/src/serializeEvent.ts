// Copyright Andreas Alin <andreas.alin@gmail.com>
// License: AGPL-3.0

export default function serializeEvent(e: Event) {
  const payload: Record<string, any> = {};

  payload.type = e.constructor.name;
  payload.eventType = e.type;
  payload.bubbles = e.bubbles;
  payload.cancelable = e.cancelable;
  payload.defaultPrevented = e.defaultPrevented;
  payload.timeStamp = e.timeStamp;

  if (e.currentTarget instanceof Element) {
    payload.currentTarget = serializeElement(e.currentTarget);
  }

  if (e.target instanceof Element) {
    payload.target = serializeElement(e.target);
  }

  if (e instanceof KeyboardEvent) {
    payload.key = e.key;
    payload.code = e.code;
    payload.keyCode = e.keyCode;
    payload.location = e.location;
    payload.isComposing = e.isComposing;
    Object.assign(payload, serializeModifierKeys(e));
    payload.repeat = e.repeat;
  }

  if (e instanceof MouseEvent) {
    payload.button = e.button;
    payload.buttons = e.buttons;
    payload.clientX = e.clientX;
    payload.clientY = e.clientY;
    Object.assign(payload, serializeModifierKeys(e));
  }

  if (e instanceof FocusEvent && e.relatedTarget instanceof Element) {
    payload.relatedTarget = serializeElement(e.relatedTarget);
  }

  if (typeof InputEvent !== "undefined" && e instanceof InputEvent) {
    payload.data = e.data;
    payload.inputType = e.inputType;
    payload.isComposing = e.isComposing;
  }

  if (typeof WheelEvent !== "undefined" && e instanceof WheelEvent) {
    payload.deltaX = e.deltaX;
    payload.deltaY = e.deltaY;
    payload.deltaZ = e.deltaZ;
    payload.deltaMode = e.deltaMode;
  }

  if (typeof PointerEvent !== "undefined" && e instanceof PointerEvent) {
    payload.pointerId = e.pointerId;
    payload.pointerType = e.pointerType;
    payload.isPrimary = e.isPrimary;
    payload.pressure = e.pressure;
  }

  if (e instanceof SubmitEvent) {
    if (e.submitter instanceof HTMLElement) {
      payload.submitter = serializeElement(e.submitter);
    }
  }

  return payload;
}

function serializeElement(elem: Element) {
  const base = {
    tagName: elem.tagName,
    id: elem.id,
    dataset: serializeDataset(elem),
  };

  if (elem instanceof HTMLInputElement) {
    const valueAsNumber = Number.isNaN(elem.valueAsNumber)
      ? null
      : elem.valueAsNumber;

    return {
      ...base,
      type: elem.type,
      name: elem.name,
      value: elem.value,
      valueAsNumber,
      checked: elem.checked,
      indeterminate: elem.indeterminate,
      disabled: elem.disabled,
      readOnly: elem.readOnly,
      required: elem.required,
      files: elem.files ? Array.from(elem.files, serializeFile) : [],
    };
  }

  if (elem instanceof HTMLTextAreaElement) {
    return {
      ...base,
      name: elem.name,
      value: elem.value,
      selectionStart: elem.selectionStart,
      selectionEnd: elem.selectionEnd,
      disabled: elem.disabled,
      readOnly: elem.readOnly,
      required: elem.required,
    };
  }

  if (elem instanceof HTMLSelectElement) {
    return {
      ...base,
      type: elem.type,
      name: elem.name,
      value: elem.value,
      selectedIndex: elem.selectedIndex,
      multiple: elem.multiple,
      selectedOptions: Array.from(
        elem.selectedOptions,
        (option) => option.value
      ),
      disabled: elem.disabled,
      required: elem.required,
    };
  }

  if (elem instanceof HTMLFormElement) {
    const formData = serializeFormData(elem);

    return {
      ...base,
      method: elem.method,
      target: elem.target,
      action: elem.action,
      enctype: elem.enctype,
      noValidate: elem.noValidate,
      name: elem.name,
      formData,
    };
  }

  if (elem instanceof HTMLDetailsElement) {
    return {
      ...base,
      open: elem.open,
    };
  }

  if (elem instanceof HTMLDialogElement) {
    return {
      ...base,
      open: elem.open,
      returnValue: elem.returnValue,
    };
  }

  if (elem instanceof HTMLButtonElement) {
    return {
      ...base,
      type: elem.type,
      name: elem.name,
      value: elem.value,
      disabled: elem.disabled,
    };
  }

  return base;
}

function serializeDataset(elem: Element) {
  if (!(elem instanceof HTMLElement || elem instanceof SVGElement)) return {};
  return { ...elem.dataset };
}

function serializeModifierKeys(
  e: Pick<MouseEvent, "ctrlKey" | "metaKey" | "shiftKey" | "altKey">
) {
  return {
    ctrlKey: e.ctrlKey,
    metaKey: e.metaKey,
    shiftKey: e.shiftKey,
    altKey: e.altKey,
  };
}

function serializeFormData(form: HTMLFormElement) {
  const formData: Record<string, any> = {};

  for (const [key, value] of new FormData(form).entries()) {
    const serializedValue = serializeFormDataValue(value);
    const existing = formData[key];

    if (typeof existing === "undefined") {
      formData[key] = serializedValue;
    } else if (Array.isArray(existing)) {
      existing.push(serializedValue);
    } else {
      formData[key] = [existing, serializedValue];
    }
  }

  return formData;
}

function serializeFormDataValue(value: FormDataEntryValue) {
  if (typeof value === "string") return value;
  return serializeFile(value);
}

function serializeFile(file: File) {
  return {
    name: file.name,
    type: file.type,
    size: file.size,
  };
}
