// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { SESSION_MIME_TYPE, STREAM_MIME_TYPE } from "../protocol/constants";
import { StreamError, streamErrorFromResponse } from "./stream-error";

// Opens the stream of command batches from the server. With a transfer
// state, the session is first restored from it on the server that answers.
export async function openCommandStream(
  endpoint: string,
  state: Blob | null = null,
  signal?: AbortSignal,
): Promise<ReadableStream<Uint8Array>> {
  const res = await connect(endpoint, state, signal);

  if (!res.body) throw new Error("No body");

  const contentEncoding = res.headers.get("content-encoding");

  if (!contentEncoding) return res.body;

  return res.body.pipeThrough(
    new DecompressionStream(contentEncoding as CompressionFormat),
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

  console.info("🟢 Connected to", endpoint);

  return res;
}
