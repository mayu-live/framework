// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Messages between the page and the devtools. They travel
//
//   hook (page) <-postMessage-> bridge <-runtime messages-> background
//     <-port-> devtools page and panel
//
// Every message crossing window.postMessage is tagged with its direction, so
// the hook and the bridge ignore each other's echoes and the page's own
// messages.

import type { BatchEntry } from "./batch";

// The port the devtools connect to the background with.
export const PORT_NAME = "mayu-devtools";

export const FROM_PAGE = "mayu-devtools:page";
export const FROM_DEVTOOLS = "mayu-devtools:devtools";

// Sent by the page.
export type PageMessage =
  | { type: "detected" }
  | { type: "batch"; entries: BatchEntry[] }
  | {
      type: "inspect-result";
      requestId: string;
      result?: unknown;
      error?: string;
    };

// Sent by the devtools.
export type DevtoolsMessage =
  | { type: "hello" }
  | { type: "inspect"; requestId: string; query: Record<string, unknown> };

export type Tagged<T> = T & { source: string };

// Only checks the tag: the hook and the bridge trust each other.
export function isTagged<T>(data: unknown, source: string): data is Tagged<T> {
  return (
    typeof data === "object" &&
    data !== null &&
    (data as { source?: unknown }).source === source
  );
}
