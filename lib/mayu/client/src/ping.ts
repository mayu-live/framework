import type MayuPing from "./custom-elements/mayu-ping";

import("./custom-elements/mayu-ping");

function getPingElement() {
  return document.querySelector<MayuPing>("mayu-ping");
}

export function updatePing(value: number) {
  getPingElement()?.setAttribute("ping", `${value.toFixed(2)}ms`);
}

export function updateConnectionStatus(
  status: "disconnected" | "connected" | "transferring",
) {
  getPingElement()?.setAttribute("status", status);
}
