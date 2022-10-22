import { sessionStream } from "./stream";
import NodeTree from "./NodeTree";
import type MayuPingElement from "./custom-elements/mayu-ping";
import defineCustomElements from "./custom-elements";
defineCustomElements();

const onDOMContentLoaded = new Promise<void>((resolve) => {
  if (document.readyState !== "loading") {
    return resolve();
  }

  window.addEventListener("DOMContentLoaded", () => resolve());
});

class MayuGlobal {
  #sessionId: string;

  constructor(sessionId: string) {
    this.#sessionId = sessionId;
  }

  async handle(e: Event, handlerId: string) {
    e.preventDefault();

    const payload = {
      type: e.type,
      value: (e.target as any).value,
    } as Record<string, any>;

    if (e.target instanceof HTMLFormElement) {
      payload.formData = Object.fromEntries(new FormData(e.target).entries());

      if (
        e instanceof SubmitEvent &&
        e.submitter instanceof HTMLButtonElement &&
        e.submitter.name
      ) {
        payload.formData[e.submitter.name] = e.submitter.value;
      }
    }

    // progressBar.setAttribute("progress", "0");

    await mayuCallback(this.#sessionId, handlerId, payload);

    let didRun = false;
    const timeout = setTimeout(() => {
      // progressBar.setAttribute("progress", "25");
      didRun = true;
    }, 1);

    clearTimeout(timeout);

    // progressBar.setAttribute("progress", "100");
  }

  async navigate(e: MouseEvent) {
    if (e.metaKey || e.ctrlKey) return;

    e.preventDefault();
    const anchor = (e.target as HTMLElement).closest("a");

    if (!anchor) {
      console.error("Could not find anchor element for", e.target);
      return;
    }

    const url = new URL((anchor as HTMLAnchorElement).href);
    // progressBar.setAttribute("progress", "0");
    return navigateTo(this.#sessionId, url.pathname + url.search);
  }
}

function mayuCallback(sessionId: string, handlerId: string, payload: any) {
  return fetch(`/__mayu/session/${sessionId}/callback/${handlerId}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
}

async function navigateTo(sessionId: string, url: string) {
  return fetch(`/__mayu/session/${sessionId}/navigate`, {
    method: "POST",
    headers: { "content-type": "text/plain" },
    body: url,
  });
}

function getSessionIdFromUrl() {
  const url = import.meta.url;
  const index = url.lastIndexOf("#");
  if (index === -1) {
    throw new Error("No # found in script url");
  }
  return url.slice(index + 1);
}

async function main() {
  const sessionId = getSessionIdFromUrl();
  const mayu = new MayuGlobal(sessionId);
  window.Mayu = mayu;

  let nodeTree: NodeTree | undefined;

  const disconnectedElement = document.createElement("mayu-disconnected");
  const pingElement = document.createElement("mayu-ping") as MayuPingElement;
  document.body.appendChild(pingElement);

  for await (const [event, payload] of sessionStream(sessionId)) {
    switch (event) {
      case "system.connected":
        pingElement.setAttribute("region", "Connected!");
        pingElement.setAttribute("status", "connected");
        document.body
          .querySelectorAll("mayu-disconnected")
          .forEach((el) => el.remove());
        break;
      case "system.disconnected":
        if (payload.transferring) {
          pingElement.setAttribute("region", "Transferring…");
          pingElement.setAttribute("status", "transferring");
          break;
        }

        pingElement.setAttribute("region", "Disconnected");
        pingElement.setAttribute("status", "disconnected");

        console.error("Disconnected");
        if (disconnectedElement.parentElement !== document.body) {
          document.body.appendChild(disconnectedElement);
        }
        break;
      case "session.init":
        await onDOMContentLoaded;
        nodeTree = new NodeTree(payload.ids);
        break;
      case "session.patch":
        nodeTree?.apply(payload);
        break;
      case "session.navigate":
        const path = payload.path;
        console.log("Navigating to", path);
        history.pushState({}, "", path);
        // progressBar.setAttribute("progress", "100");
        break;
      case "session.keep_alive":
        break;
      case "session.transfer":
        pingElement.setAttribute("region", "Transferring");
        pingElement.setAttribute("status", "transferring");
        break;
      case "ping":
        const values = Object.values(payload.values) as number[];
        const mean = values.reduce((a, b) => a + b, 0.0) / values.length;
        // console.table({
        //   client: { ping: payload.values.client },
        //   server: { ping: payload.values.server },
        //   mean: { ping: mean },
        // });
        pingElement.setAttribute("ping", `${mean.toFixed(2)} ms`);
        pingElement.setAttribute("region", payload.region);
        pingElement.setAttribute("status", "ping");
        break;
      default:
        console.warn("Unhandled event:", event, payload);
        break;
    }
  }
}

export default main();
