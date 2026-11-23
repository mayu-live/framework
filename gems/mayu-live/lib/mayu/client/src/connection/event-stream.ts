// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { STREAM_MIME_TYPE } from "../protocol/constants";
import {
  isAbortError,
  StreamError,
  streamErrorFromResponse,
} from "./stream-error";
import supportsRequestStreams from "./supports-request-streams";

const EVENT_STREAM_METHOD = "PATCH";

export type EventStreamConnection = {
  // Takes encoded event frames.
  writable: WritableStream<Uint8Array<ArrayBuffer>>;
  // Rejects when the request ends, which it never should while connected.
  // Null when every event is its own request.
  failure: Promise<never> | null;
};

// Opens the stream of events to the server: one long-lived request where
// the browser can stream a request body, and one request per event where it
// can't. Both send the same frame bytes.
export function openEventStream(
  endpoint: string,
  signal?: AbortSignal,
): EventStreamConnection {
  if (!supportsRequestStreams) {
    console.warn("Request streams not supported, using fallback.");
    return openEventStreamFallback(endpoint, signal);
  }

  const { readable, writable } = new TransformStream<
    Uint8Array<ArrayBuffer>,
    Uint8Array<ArrayBuffer>
  >();

  const failure = fetch(endpoint, {
    method: EVENT_STREAM_METHOD,
    credentials: "include",
    headers: new Headers({
      "content-type": STREAM_MIME_TYPE,
    }),
    duplex: "half",
    mode: "cors",
    signal,
    body: readable,
  } as RequestInit).then(async (res) => {
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

function openEventStreamFallback(
  endpoint: string,
  signal?: AbortSignal,
): EventStreamConnection {
  return {
    writable: new WritableStream<Uint8Array<ArrayBuffer>>({
      async write(body) {
        try {
          const res = await fetch(endpoint, {
            method: EVENT_STREAM_METHOD,
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
