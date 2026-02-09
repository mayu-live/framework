import { SESSION_PATH } from "./constants";
import { setTransferState } from "./transfer";
import withViewTransition from "./view-transition";

const RESET_SESSION_ERROR_MESSAGES = new Set([
  "expired",
  "cipher error",
  "session not found",
  "token cookie not set",
]);

export function getErrorMessage(error: unknown): string | null {
  if (typeof error === "string") return error;
  if (error instanceof Error) return error.message;
  return null;
}

export function shouldResetSession(error: unknown): boolean {
  const message = getErrorMessage(error);
  if (!message) return false;

  return RESET_SESSION_ERROR_MESSAGES.has(message.toLowerCase());
}

export async function resetSessionEntirely() {
  const [morphdom, res] = await Promise.all([
    import("morphdom"),
    fetch(location.pathname + location.search, {
      method: "GET",
      credentials: "include",
      headers: new Headers({
        accept: "text/html",
      }),
    }),
  ]);

  const html = (await res.text()).replace(/^<!DOCTYPE html>\n/, "");
  const sessionId = res.headers.get("x-mayu-session-id");

  if (!sessionId) {
    throw new Error("Missing x-mayu-session-id header during session reset");
  }

  console.warn(
    `%cmorphing dom`,
    "font-size: 4em; font-weight: bold; font-family: monospace;"
  );

  await withViewTransition(async () => {
    morphdom.default(document.documentElement, html);
  });

  setTransferState(null);

  return `${SESSION_PATH}/${sessionId}`;
}
