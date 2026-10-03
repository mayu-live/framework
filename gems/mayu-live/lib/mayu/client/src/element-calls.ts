// The element methods a server can call through `ref.current`, by the
// snake_case name the server sends. Keep in sync with ElementHandle in
// runtime/ref.rb. Only names in this table are ever called.
export const ELEMENT_METHODS = Object.freeze({
  focus: "focus",
  blur: "blur",
  click: "click",
  select: "select",
  reset: "reset",
  request_submit: "requestSubmit",
  scroll_into_view: "scrollIntoView",
  set_selection_range: "setSelectionRange",
  show_modal: "showModal",
  show: "show",
  close: "close",
  show_popover: "showPopover",
  hide_popover: "hidePopover",
  toggle_popover: "togglePopover",
} as const);

// Calls are fire-and-forget, so a call that can't be made is reported in the
// console instead of failing the batch it came in: the element may have been
// removed by the same batch, or the method may not apply to it, such as
// show_modal on a dialog that is already open.
export function callElementMethod(
  node: Node | undefined,
  name: string,
  args: unknown[],
) {
  if (!Object.hasOwn(ELEMENT_METHODS, name)) {
    console.warn(`Unknown element method: ${name}`);
    return;
  }

  if (!(node instanceof Element)) {
    console.warn(`Can't call ${name}: the element is gone`);
    return;
  }

  const methodName = ELEMENT_METHODS[name as keyof typeof ELEMENT_METHODS];
  const method = (node as unknown as Record<string, unknown>)[methodName];

  if (typeof method !== "function") {
    console.warn(`Can't call ${name} on <${node.localName}>`);
    return;
  }

  try {
    method.apply(node, args);
  } catch (error) {
    console.warn(`Calling ${name} on <${node.localName}> failed`, error);
  }
}
