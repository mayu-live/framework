import type MayuPing from "./custom-elements/mayu-ping";

import("./custom-elements/mayu-ping");

export type ConnectionStatus = "disconnected" | "connected" | "transferring";
export type NavigationProgressState = "pending" | "complete";
export type ReconnectStatus = {
  attempt: number;
  // Epoch milliseconds of the next attempt, or null while an attempt is running.
  retryAt: number | null;
};

function getPingElement() {
  return document.querySelector<MayuPing>("mayu-ping");
}

export function updatePing(value: number) {
  getPingElement()?.setAttribute("ping", `${Math.round(value)}ms`);
}

export function updateConnectionStatus(status: ConnectionStatus) {
  getPingElement()?.setAttribute("status", status);
}

export function updateReconnectStatus(status: ReconnectStatus | null) {
  const element = getPingElement();
  if (!element) return;

  if (status?.retryAt) {
    element.setAttribute("reconnect-at", String(status.retryAt));
  } else {
    element.removeAttribute("reconnect-at");
  }

  if (status) {
    element.setAttribute("reconnect-attempt", String(status.attempt));
  } else {
    element.removeAttribute("reconnect-attempt");
  }
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
