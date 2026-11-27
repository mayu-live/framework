// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import {
  LAST_BATCH_HEADER,
  PROTOCOL_HEADER,
  PROTOCOL_VERSION,
  SESSION_MIME_TYPE,
  STREAM_MIME_TYPE,
} from "../protocol/constants";
import { StreamError, streamErrorFromResponse } from "./stream-error";

// A request for the command stream that init.ts sent before this code had
// loaded, and what cancels it.
export type EarlyStream = {
  response: Promise<Response>;
  controller: AbortController;
};

// Opens the stream of command batches from the server. With a transfer
// state, the session is first restored from it on the server that answers.
// Otherwise `lastBatch` names the last batch this page applied, if any, and
// the server sends what came after it. With `early`, the request is already
// on its way and its response is the one that is read.
export async function openCommandStream(
  endpoint: string,
  state: Blob | null = null,
  signal?: AbortSignal,
  lastBatch: number | null = null,
  early: EarlyStream | null = null,
): Promise<ReadableStream<Uint8Array>> {
  const res = await connect(endpoint, state, signal, lastBatch, early);

  if (!res.body) throw new Error("No body");

  const contentEncoding = res.headers.get("content-encoding");

  if (!contentEncoding) return res.body;

  return res.body.pipeThrough(
    new DecompressionStream(contentEncoding as CompressionFormat),
  );
}

// The stream is never cached. Saying so also keeps the browser from making
// this request wait for an earlier one to the same URL, which Chrome does
// for up to twenty seconds while that one is still open.
export async function connect(
  endpoint: string,
  state: Blob | null = null,
  signal?: AbortSignal,
  lastBatch: number | null = null,
  early: EarlyStream | null = null,
): Promise<Response> {
  console.info("🟡 Connecting to", endpoint);

  let res: Response | null = null;

  signal?.addEventListener("abort", () => early?.controller.abort());

  try {
    res = early
      ? await early.response
      : state
        ? await fetch(endpoint, {
            method: "POST",
            credentials: "include",
            cache: "no-store",
            signal,
            headers: new Headers({
              accept: STREAM_MIME_TYPE,
              [PROTOCOL_HEADER]: PROTOCOL_VERSION,
              "content-type": SESSION_MIME_TYPE,
            }),
            body: state,
          })
        : await fetch(endpoint, {
            method: "GET",
            credentials: "include",
            cache: "no-store",
            signal,
            headers: new Headers({
              accept: STREAM_MIME_TYPE,
              [PROTOCOL_HEADER]: PROTOCOL_VERSION,
              ...(lastBatch === null
                ? {}
                : { [LAST_BATCH_HEADER]: String(lastBatch) }),
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
    throw await streamErrorFromResponse(res, "Unknown stream error");
  }

  const contentType = res.headers.get("content-type");

  if (contentType !== STREAM_MIME_TYPE) {
    throw new StreamError(`Unexpected content type: ${contentType}`);
  }

  // A server from before the protocol had a version names none.
  if (res.headers.get(PROTOCOL_HEADER) !== PROTOCOL_VERSION) {
    throw new StreamError("Protocol mismatch", "PROTOCOL_MISMATCH");
  }

  console.info("🟢 Connected to", endpoint);

  return res;
}
