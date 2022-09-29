import NodeTree from "./NodeTree.js";
import PingTimer from "./PingTimer.js";

import type MayuPingElement from "./custom-elements/mayu-ping";
import type MayuProgressBar from "./custom-elements/mayu-progress-bar";
import defineCustomElements from "./custom-elements";
defineCustomElements();

import h from "./h";

const SESSION_ID_KEY = "mayu.sessionId";

export default async function init(encryptedState: string) {
  const sessionId = await resume(
    encryptedState,
    sessionStorage.getItem(SESSION_ID_KEY)
  );

  const disconnectedElement = document.createElement("mayu-disconnected");
  const progressBar = document.body.appendChild(
    document.createElement("mayu-progress-bar") as MayuProgressBar
  );

  window.Mayu = setupGlobalObject(sessionId, { progressBar });

  let isUnloading = false;

  window.addEventListener("beforeunload", () => {
    isUnloading = true;
  });

  const es = new EventSource(`/__mayu/session/${sessionId}/events`);

  let errorCount = 0;

  es.onopen = () => {
    errorCount = 0;
    console.log("Opened session", sessionId);
    sessionStorage.setItem(SESSION_ID_KEY, sessionId);
    startPing(es, sessionId);

    document.body
      .querySelectorAll("mayu-disconnected")
      .forEach((el) => el.remove());
  };

  es.onerror = () => {
    // console.log({ isUnloading, readyState: document.readyState });
    if (isUnloading) return;

    sessionStorage.removeItem(SESSION_ID_KEY);

    if (disconnectedElement.parentElement !== document.body) {
      document.body.appendChild(disconnectedElement);
    }

    if (errorCount++ > 5) {
      console.warn(
        "Closing event source because of this many errors:",
        errorCount
      );
      es.close();
    }
  };

  es.addEventListener("navigate", (e) => {
    const path = JSON.parse(e.data);
    console.log("Navigating to", path);
    history.pushState({}, "", path);
    progressBar.setAttribute("progress", "100");
  });

  es.addEventListener("exception", (e) => {
    const error = JSON.parse(e.data) as {
      type: string;
      message: string;
      backtrace: string[];
    };
    const { type, message, backtrace } = error;
    const cleanedBacktrace = backtrace
      .filter((line) => !/\/vendor\/bundle\//.test(line))
      .join("\n");

    const el = h("mayu-exception", [
      h("span", [`${type}: ${message}`], { slot: "title" }),
      h("span", [cleanedBacktrace], { slot: "backtrace" }),
    ]);

    document.body.appendChild(el);
  });

  window.addEventListener("popstate", () => {
    navigateTo(
      sessionId,
      document.location.pathname + document.location.search
    );
  });

  es.addEventListener(
    "init",
    (e) => {
      const { ids } = JSON.parse(e.data) as any;
      const nodeTree = new NodeTree(ids);

      es.addEventListener("patch", (e) => {
        nodeTree.apply(JSON.parse(e.data));
      });
    },
    { once: true }
  );
}

async function resume(state: string, storedSessionId: string | null) {
  const path = storedSessionId
    ? `/__mayu/session/resume/${storedSessionId}`
    : "/__mayu/session/resume";

  const res = await fetch(path, {
    method: "POST",
    headers: { "content-type": "text/plain" },
    body: state,
  });

  if (!res.ok) {
    alert("Could not resume state");
    throw new Error("Got a non-ok response from the resume endpoint");
  }

  return res.text();
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

function setupGlobalObject(
  sessionId: string,
  { progressBar }: { progressBar: MayuProgressBar }
) {
  return {
    async handle(e: Event, handlerId: string) {
      e.preventDefault();

      const payload = {
        type: e.type,
        value: (e.target as any).value,
      } as Record<string, any>;

      if (e.target instanceof HTMLFormElement) {
        payload.formData = Object.fromEntries(new FormData(e.target).entries());
      }

      progressBar.setAttribute("progress", "0");

      await mayuCallback(sessionId, handlerId, payload);

      let didRun = false;
      const timeout = setTimeout(() => {
        progressBar.setAttribute("progress", "25");
        didRun = true;
      }, 1);

      clearTimeout(timeout);

      progressBar.setAttribute("progress", "100");
    },

    async navigate(e: MouseEvent) {
      e.preventDefault();
      const anchor = (e.target as HTMLElement).closest("a");

      if (!anchor) {
        console.error("Could not find anchor element for", e.target);
        return;
      }

      const url = new URL((anchor as HTMLAnchorElement).href);
      progressBar.setAttribute("progress", "0");
      return navigateTo(sessionId, url.pathname + url.search);
    },
  };
}

async function startPing(es: EventSource, sessionId: string) {
  const pingTimer = new PingTimer();

  es.addEventListener("pong", (e) => {
    pingTimer.pong(JSON.parse(e.data));
  });

  const pingElement = document.createElement("mayu-ping") as MayuPingElement;
  document.body.appendChild(pingElement);

  async function pingLoop() {
    let running = true;

    while (running) {
      try {
        switch (es.readyState) {
          case EventSource.OPEN: {
            const { ping, region } = await pingTimer.ping(async (now) => {
              const res = await fetch(`/__mayu/session/${sessionId}/ping`, {
                method: "POST",
                headers: { "content-type": "application/json" },
                body: JSON.stringify(now),
              });

              if (res.ok) return;

              const text = await res.text();
              console.error("Non-ok response from ping:", res.status, text);
              es.close();
              running = false;
              alert("Got non-ok from ping.\n\nReloading page.");
              window.location.reload();
            });

            pingElement.setAttribute("ping", `${ping.toFixed(2)} ms`);
            pingElement.setAttribute("region", region);
            break;
          }
          case EventSource.CLOSED: {
            pingElement.setAttribute("ping", `N/A ms`);
            pingElement.setAttribute("region", "closed");
            break;
          }
          case EventSource.CONNECTING: {
            pingElement.setAttribute("ping", `N/A ms`);
            pingElement.setAttribute("region", "connecting");
            break;
          }
        }

        await pingTimer.sleep(PingTimer.PING_FREQUENCY_MS);
      } catch (e) {
        console.error("Error. Retrying in", PingTimer.RETRY_TIME_MS, "ms");
        await pingTimer.sleep(PingTimer.RETRY_TIME_MS);
      }
    }
  }

  pingLoop();
}
