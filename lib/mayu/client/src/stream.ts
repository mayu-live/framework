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
  signal?: AbortSignal
): Promise<ReadableStream<any>> {
  const res = await connect(endpoint, state, signal);

  if (!res.body) throw new Error("No body");

  const contentEncoding = res.headers.get("content-encoding");

  if (!contentEncoding) return res.body;

  return res.body.pipeThrough(new DecompressionStream(contentEncoding as any));
}

export class StreamError extends Error {}

export async function connect(
  endpoint: string,
  state: Blob | null = null,
  signal?: AbortSignal
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
    const message = await res.json();
    throw new StreamError(message.error);
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

export class JSONEncoderStream extends TransformStream {
  constructor() {
    super({
      transform(chunk, controller) {
        controller.enqueue(JSON.stringify(chunk) + "\n");
      },
    });
  }
}

function isAbortError(error: unknown): boolean {
  return error instanceof Error && error.name === "AbortError";
}

export function initCallbackStream(endpoint: string, signal?: AbortSignal) {
  if (!supportsRequestStreams) {
    console.warn("Request streams not supported, using fallback.");
    return initCallbackStreamFetchFallback(endpoint, signal);
  }

  const contentEncoding = "identity"; // STREAM_CONTENT_ENCODING;
  const { readable, writable } = new TransformStream(); // new CompressionStream(contentEncoding);

  void fetch(endpoint, {
    method: CALLBACK_STREAM_METHOD,
    headers: new Headers({
      "content-type": STREAM_MIME_TYPE,
      "content-encoding": contentEncoding,
    }),
    duplex: "half",
    mode: "cors",
    signal,
    body: readable,
  } as any).catch((error) => {
    if (isAbortError(error)) return;
    console.error("Callback stream error", error);
  });

  return writable;
}

function initCallbackStreamFetchFallback(
  endpoint: string,
  signal?: AbortSignal
) {
  return new WritableStream({
    async write(body) {
      try {
        await fetch(endpoint, {
          method: CALLBACK_STREAM_METHOD,
          headers: new Headers({
            "content-type": "application/json",
          }),
          mode: "cors",
          signal,
          body: body,
        });
      } catch (error) {
        if (isAbortError(error)) return;
        throw error;
      }
    },
  });
}
