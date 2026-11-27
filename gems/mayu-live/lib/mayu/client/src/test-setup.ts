// `ui/status.ts` loads <mayu-ping> without waiting for it. Loading it here
// first means that import is already done when a test file ends; otherwise
// it can still be running while the environment is torn down.
import "./ui/custom-elements/mayu-ping";

// jsdom implements neither modal dialogs nor popovers. These do the part
// that the runtime's own elements rely on.
HTMLDialogElement.prototype.showModal = function () {
  this.open = true;
};

HTMLDialogElement.prototype.close = function () {
  if (!this.open) return;
  this.open = false;
  this.dispatchEvent(new Event("close"));
};

// Tests can tell a shown popover by its `data-shown` attribute.
HTMLElement.prototype.showPopover = function () {
  this.setAttribute("data-shown", "");
};

HTMLElement.prototype.hidePopover = function () {
  this.removeAttribute("data-shown");
};
