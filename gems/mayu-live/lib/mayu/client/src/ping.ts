import type MayuPing from "./custom-elements/mayu-ping";

import("./custom-elements/mayu-ping");

export type ConnectionStatus = "disconnected" | "connected" | "transferring";

function getPingElement() {
  return document.querySelector<MayuPing>("mayu-ping");
}

export function updatePing(value: number) {
  getPingElement()?.setAttribute("ping", `${Math.round(value)}ms`);
}

export function updateConnectionStatus(status: ConnectionStatus) {
  getPingElement()?.setAttribute("status", status);
}
