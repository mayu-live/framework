import { SESSION_PATH } from "../protocol/constants";
import withViewTransition, {
  type ViewTransitionRoot,
} from "../ui/view-transition";

export const RESET_SESSION_ERROR_CODES = new Set([
  "TRANSFER_FAILED",
  "SESSION_EXPIRED",
  "SESSION_CIPHER_ERROR",
  "SESSION_RESTORE_FAILED",
  "SESSION_NOT_FOUND",
  "TOKEN_COOKIE_NOT_SET",
]);

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

  return code !== null && RESET_SESSION_ERROR_CODES.has(code);
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

  await withViewTransition(
    document as unknown as ViewTransitionRoot,
    async () => {
      morphdom.default(document.documentElement, html);
    },
    ["session-recovery"],
  );

  return `${SESSION_PATH}/${sessionId}`;
}
