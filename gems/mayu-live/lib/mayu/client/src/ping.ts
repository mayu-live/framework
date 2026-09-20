import type MayuPing from "./custom-elements/mayu-ping";

import("./custom-elements/mayu-ping");

export type ConnectionStatus = "disconnected" | "connected" | "transferring";
export type NavigationProgressState = "pending" | "complete";

function getPingElement() {
  return document.querySelector<MayuPing>("mayu-ping");
}

export function updatePing(value: number) {
  getPingElement()?.setAttribute("ping", `${Math.round(value)}ms`);
}

export function updateConnectionStatus(status: ConnectionStatus) {
  getPingElement()?.setAttribute("status", status);
}

export function updateNavigationProgress(
  state: NavigationProgressState | null,
) {
  const element = getPingElement();
  if (!element) return;

  if (state) {
    element.setAttribute("navigation", state);
  } else {
    element.removeAttribute("navigation");
  }
}
