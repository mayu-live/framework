import Runtime from "./runtime.js";

import {
  initInputStream,
  initCallbackStream,
  JSONEncoderStream,
} from "./stream.js";

import serializeEvent from "./serializeEvent.js";
import { decodeMultiStream, ExtensionCodec } from "@msgpack/msgpack";

import { SESSION_MIME_TYPE, SESSION_PATH, PING_INTERVAL } from "./constants";
import { updateConnectionStatus } from "./ping";
import { getTransferState, setTransferState } from "./transfer";
import throttle from "./throttle";

import "./custom-elements/mayu-exception";

declare global {
  interface Window {
    Mayu: Mayu;
  }

  interface Document {
    startViewTransition?: (callback: () => void) => void;
  }
}

class Mayu {
  #writer: WritableStreamDefaultWriter<any> | null;
  #pingTimer: NodeJS.Timeout;

  constructor() {
    this.#writer = null;

    window.addEventListener("popstate", () => {
      this.navigate(location.pathname + location.search, false);
    });

    this.#pingTimer = setTimeout(() => this.ping(), 100);
  }

  setWriter(writer: WritableStreamDefaultWriter<any>) {
    this.#writer = writer;
  }

  async #write(message: any) {
    try {
      await this.#writer?.write(message);
    } catch (e) {
      console.error("Write error");
    }
  }

  callback(event: Event, id: string) {
    event.preventDefault();

    const serializedEvent = serializeEvent(event);
    throttle(event.currentTarget!, () => {
      this.#write({
        type: "callback",
        payload: { id, event: serializedEvent },
        ping: performance.now(),
      });
    });
  }

  navigate(href: string, pushState: boolean = true) {
    console.warn("navigate", href);
    this.#write({
      type: "navigate",
      payload: { href, pushState },
      ping: performance.now(),
    });
  }

  ping() {
    clearTimeout(this.#pingTimer);

    this.#pingTimer = setTimeout(() => this.ping(), PING_INTERVAL);

    this.#write({
      type: "ping",
      ping: performance.now(),
    });
  }
}

async function sleep(milliseconds: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, milliseconds));
}

async function resetSessionEntirely() {
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

  console.warn(
    `%cmorphing dom`,
    "font-size: 4em; font-weight: bold; font-family: monospace;"
  );

  if (document.startViewTransition) {
    document.startViewTransition(async () => {
      morphdom.default(document.documentElement, html);
    });
  } else {
    morphdom.default(document.documentElement, html);
  }

  setTransferState(null);

  return `${SESSION_PATH}/${sessionId}`;
}

async function startPatchStream(runtime: Runtime, endpoint: string) {
  const extensionCodec = createExtensionCodec();
  let failures = 0;

  while (true) {
    try {
      const state = getTransferState();

      updateConnectionStatus(state ? "transferring" : "disconnected");

      const input = await initInputStream(endpoint, state);
      setTransferState(null);

      const callbackStream = new TransformStream();
      window.Mayu.setWriter(callbackStream.writable.getWriter());
      const output = initCallbackStream(endpoint);

      failures = 0;

      callbackStream.readable
        .pipeThrough(new JSONEncoderStream())
        .pipeThrough(new TextEncoderStream())
        .pipeTo(output);

      updateConnectionStatus("connected");

      for await (const patch of decodeMultiStream(input, { extensionCodec })) {
        updateConnectionStatus("connected");
        runtime.apply(patch as any);
      }
    } catch (e: any) {
      failures += 1;

      if (e.message === "expired" || e.message === "cipher error") {
        console.warn("Resetting session because of:", e.message);
        endpoint = await resetSessionEntirely();
      } else {
        await sleep(Math.min(10_000, 1000 * failures + 1));
      }
    }
  }
}

function createExtensionCodec() {
  const extensionCodec = new ExtensionCodec();

  extensionCodec.register({
    type: 0x01,
    encode() {
      throw new Error("Not implemented");
    },
    decode(buffer) {
      return new Blob([buffer], { type: SESSION_MIME_TYPE });
    },
  });

  return extensionCodec;
}

function main() {
  const sheet = new CSSStyleSheet();
  sheet.replaceSync(`
  ::view-transition-old(root),
  ::view-transition-new(root) {
    animation-duration: 1s;
  }
  `);
  document.adoptedStyleSheets.push(sheet);

  const runtime = new Runtime();

  window.Mayu = new Mayu();

  const sessionId = import.meta.url.split("#").at(-1);
  const endpoint = `${SESSION_PATH}/${sessionId}`;
  startPatchStream(runtime, endpoint);
}

if (window.Mayu) {
  console.error(
    "%cwindow.Mayu is already defined",
    "font-size: 1.5em; color: #c00;"
  );
} else {
  main();
}
