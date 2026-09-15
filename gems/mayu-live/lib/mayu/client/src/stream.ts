// Copyright Andreas Alin <andreas.alin@gmail.com>
// License: AGPL-3.0

import {
  STREAM_MIME_TYPE,
  STREAM_CONTENT_ENCODING,
  SESSION_MIME_TYPE,
} from "./constants";

import supportsRequestStreams from "./supportsRequestStreams";

const CALLBACK_STREAM_METHOD = "PATCH";

export async function initInputStream(
  endpoint: string,
  state: Blob | null = null,
  signal?: AbortSignal,
): Promise<ReadableStream<any>> {
  const res = await connect(endpoint, state, signal);

  if (!res.body) throw new Error("No body");

  const contentEncoding = res.headers.get("content-encoding");

  if (!contentEncoding) return res.body;

  return res.body.pipeThrough(new DecompressionStream(contentEncoding as any));
}

export class StreamError extends Error {
  code: string | null;

  constructor(message: string, code: string | null = null) {
    super(message);
    this.name = "StreamError";
    this.code = code;
  }
}

function parseErrorResponse(payload: unknown): {
  message: string;
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

    if ("error" in payload && typeof payload.error === "string") {
      return { message: payload.error, code };
    }
  }

  if (typeof payload === "string") {
    return { message: payload, code: null };
  }

  return { message: "Unknown stream error", code: null };
}

async function streamErrorFromResponse(
  res: Response,
  fallback: string,
): Promise<StreamError> {
  let payload: unknown = null;
  try {
    payload = await res.json();
  } catch (_error) {}
  const { message, code } = parseErrorResponse(payload);
  return new StreamError(
    message === "Unknown stream error" ? fallback : message,
    code,
  );
}

export async function connect(
  endpoint: string,
  state: Blob | null = null,
  signal?: AbortSignal,
): Promise<Response> {
  console.info("🟡 Connecting to", endpoint);

  let res: Response | null = null;

  try {
    res = state
      ? await fetch(endpoint, {
          method: "POST",
          credentials: "include",
          signal,
          headers: new Headers({
            accept: STREAM_MIME_TYPE,
            "accept-encoding": STREAM_CONTENT_ENCODING,
            "content-type": SESSION_MIME_TYPE,
          }),
          body: state,
        })
      : await fetch(endpoint, {
          method: "GET",
          credentials: "include",
          signal,
          headers: new Headers({
            accept: STREAM_MIME_TYPE,
            "accept-encoding": STREAM_CONTENT_ENCODING,
          }),
        });
  } catch (e) {
    if (e instanceof Error) {
      throw new StreamError(e.message);
    } else {
      throw new StreamError("Unknown error");
    }
  }

  if (!res.ok) {
    let payload: unknown = null;

    try {
      payload = await res.json();
    } catch (_error) {}

    const { message, code } = parseErrorResponse(payload);
    throw new StreamError(message, code);
  }

  const contentType = res.headers.get("content-type");

  if (contentType !== STREAM_MIME_TYPE) {
    // alert(`Unexpected content type: ${contentType}`);
    // console.error(res);
    throw new StreamError(`Unexpected content type: ${contentType}`);
  }

  console.info("🟢 Connected to", endpoint);

  return res;
}

export class RAFQueue<T> {
  onFlush: (queue: T[]) => void;
  queue: T[];
  raf: number | null;

  constructor(onFlush: (queue: T[]) => void) {
    this.onFlush = onFlush;
    this.queue = [];
    this.raf = null;
  }

  enqueue(messages: T[]) {
    messages.forEach((msg) => this.queue.push(msg));
    this.raf ||= requestAnimationFrame(() => this.flush());
  }

  flush() {
    this.raf = null;
    const queue = this.queue;
    if (queue.length === 0) return;
    this.queue = [];
    this.onFlush(queue);
  }
}

function isAbortError(error: unknown): boolean {
  return error instanceof Error && error.name === "AbortError";
}

export type CallbackStreamConnection = {
  writable: WritableStream<Uint8Array>;
  failure: Promise<never> | null;
};

export function initCallbackStream(
  endpoint: string,
  signal?: AbortSignal,
): CallbackStreamConnection {
  if (!supportsRequestStreams) {
    console.warn("Request streams not supported, using fallback.");
    return initCallbackStreamFetchFallback(endpoint, signal);
  }

  const { readable, writable } = new TransformStream<Uint8Array, Uint8Array>();

  const failure = fetch(endpoint, {
    method: CALLBACK_STREAM_METHOD,
    credentials: "include",
    headers: new Headers({
      "content-type": STREAM_MIME_TYPE,
    }),
    duplex: "half",
    mode: "cors",
    signal,
    body: readable,
  } as any).then(async (res) => {
    if (!res.ok) {
      throw await streamErrorFromResponse(
        res,
        `Callback stream failed: ${res.status}`,
      );
    }

    throw new StreamError("Callback stream ended");
  });
  void failure.catch(() => undefined);

  return { writable, failure };
}

function initCallbackStreamFetchFallback(
  endpoint: string,
  signal?: AbortSignal,
) {
  return {
    writable: new WritableStream<Uint8Array>({
      async write(body) {
        try {
          const res = await fetch(endpoint, {
            method: CALLBACK_STREAM_METHOD,
            credentials: "include",
            headers: new Headers({
              "content-type": STREAM_MIME_TYPE,
            }),
            mode: "cors",
            signal,
            body: body,
          });
          if (!res.ok) {
            throw await streamErrorFromResponse(
              res,
              `Callback request failed: ${res.status}`,
            );
          }
        } catch (error) {
          if (isAbortError(error)) return;
          throw error;
        }
      },
    }),
    failure: null,
  };
}
