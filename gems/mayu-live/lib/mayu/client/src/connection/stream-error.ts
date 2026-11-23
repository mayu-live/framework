// A failure of either stream. `code` is the server's machine-readable error
// code, when the server answered with one.
export class StreamError extends Error {
  code: string | null;

  constructor(message: string, code: string | null = null) {
    super(message);
    this.name = "StreamError";
    this.code = code;
  }
}

function parseErrorResponse(payload: unknown): {
  message: string | null;
  code: string | null;
} {
  if (payload && typeof payload === "object") {
    const code =
      "code" in payload && typeof payload.code === "string"
        ? payload.code
        : null;

    if ("message" in payload && typeof payload.message === "string") {
      return { message: payload.message, code };
    }
  }

  if (typeof payload === "string") {
    return { message: payload, code: null };
  }

  return { message: null, code: null };
}

// The server answers a failed request with JSON: `{ code, message }`.
export async function streamErrorFromResponse(
  res: Response,
  fallback: string,
): Promise<StreamError> {
  let payload: unknown = null;
  try {
    payload = await res.json();
  } catch (_error) {}
  const { message, code } = parseErrorResponse(payload);
  return new StreamError(message ?? fallback, code);
}

export function isAbortError(error: unknown): boolean {
  return error instanceof Error && error.name === "AbortError";
}
