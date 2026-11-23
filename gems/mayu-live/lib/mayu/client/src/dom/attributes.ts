type AttributeElement = HTMLElement | SVGElement;

// Sets an attribute, or the property behind it where the attribute alone
// would not change what the user sees.
export function setAttribute(
  element: AttributeElement,
  name: string,
  value: string,
) {
  if (name === "open") {
    if (element instanceof HTMLDialogElement) {
      element.showModal();
    }
  }

  if (
    element instanceof HTMLTextAreaElement &&
    (name === "value" || name === "initial_value")
  ) {
    if (name === "value") element.value = value;
    // The corresponding text-node patch updates the reset default without
    // replacing the node adopted during hydration.
    return;
  }

  if (element instanceof HTMLInputElement) {
    switch (name) {
      case "value": {
        element.value = value;
        break;
      }
      case "checked": {
        element.checked = true;
        break;
      }
      case "indeterminate": {
        element.indeterminate = true;
        return;
      }
    }
  }

  // The one name that is not an attribute's own: it sets the default
  // value and leaves the current one alone.
  if (name === "initial_value") name = "value";

  element.setAttribute(name, value);
}

export function removeAttribute(element: AttributeElement, name: string) {
  if (name === "open") {
    if (element instanceof HTMLDialogElement) {
      element.open = false;
      element.close();
    }
  }

  if (
    element instanceof HTMLTextAreaElement &&
    (name === "value" || name === "initial_value")
  ) {
    // Mark the value dirty before its default text changes.
    if (name === "value") element.value = element.value;
    return;
  }

  if (element instanceof HTMLInputElement) {
    switch (name) {
      case "value": {
        element.value = "";
        break;
      }
      case "checked": {
        element.checked = false;
        break;
      }
      case "indeterminate": {
        element.indeterminate = false;
        return;
      }
    }
  }

  // The one name that is not an attribute's own: it sets the default
  // value and leaves the current one alone.
  if (name === "initial_value") name = "value";

  element.removeAttribute(name);
}
