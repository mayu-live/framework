import { SESSION_PATH } from "./constants";
import { setTransferState } from "./transfer";
import { streamErrorFromResponse } from "./stream";
import withViewTransition, { type ViewTransitionRoot } from "./view-transition";

const RESET_SESSION_ERROR_CODES = new Set([
  "TRANSFER_FAILED",
  "EXPIRED",
  "SESSION_EXPIRED",
  "CIPHER_ERROR",
  "SESSION_CIPHER_ERROR",
  "SESSION_RESTORE_FAILED",
  "SESSION_NOT_FOUND",
  "TOKEN_COOKIE_NOT_SET",
]);

function normalizeErrorToken(value: string): string {
  return value.trim().toUpperCase().replaceAll(/\s+/g, "_");
}

export function getErrorMessage(error: unknown): string | null {
  if (typeof error === "string") return error;
  if (error instanceof Error) return error.message;
  return null;
}

export function getErrorCode(error: unknown): string | null {
  if (!error || typeof error !== "object") return null;
  if (!("code" in error)) return null;

  return typeof error.code === "string" ? error.code : null;
}

export function shouldResetSession(error: unknown): boolean {
  const code = getErrorCode(error);

  if (code && RESET_SESSION_ERROR_CODES.has(normalizeErrorToken(code))) {
    return true;
  }

  const message = getErrorMessage(error);
  if (!message) return false;

  return RESET_SESSION_ERROR_CODES.has(normalizeErrorToken(message));
}

export async function resetSessionEntirely() {
  const res = await fetch(location.pathname + location.search, {
    method: "GET",
    credentials: "include",
    headers: new Headers({
      accept: "text/html",
      "x-mayu-session-recovery": "1",
    }),
  });
  if (!res.ok) {
    throw await streamErrorFromResponse(res, "Session reset failed");
  }

  const sessionId = res.headers.get("x-mayu-session-id");

  if (!sessionId) {
    throw new Error("Missing x-mayu-session-id header during session reset");
  }

  const [morphdom, body] = await Promise.all([import("morphdom"), res.text()]);
  const html = body.replace(/^<!DOCTYPE html>\n/, "");

  console.warn(
    `%cmorphing dom`,
    "font-size: 4em; font-weight: bold; font-family: monospace;",
  );

  await withViewTransition(
    document as unknown as ViewTransitionRoot,
    async () => {
      morphdom.default(document.documentElement, html);
    },
    ["session-recovery"],
  );

  setTransferState(null);

  return `${SESSION_PATH}/${sessionId}`;
}
