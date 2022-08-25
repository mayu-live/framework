import NodeTree from "./NodeTree.js";
import PingTimer from "./PingTimer.js";

import type MayuPingElement from "./custom-elements/mayu-ping";
import type MayuProgressBar from "./custom-elements/mayu-progress-bar";
import defineCustomElements from "./custom-elements";
defineCustomElements();

const SESSION_ID_KEY = "mayu.sessionId";

export default async function init(encryptedState: string) {
  const sessionId = await resume(
    encryptedState,
    sessionStorage.getItem(SESSION_ID_KEY)
  );

  window.Mayu = setupGlobalObject(sessionId);

  let isUnloading = false;

  window.addEventListener("beforeunload", () => {
    isUnloading = true;
  });

  const es = new EventSource(`/__mayu/api/events/${sessionId}`);

  es.onopen = () => {
    console.log("Opened session", sessionId);
    sessionStorage.setItem(SESSION_ID_KEY, sessionId);
    startPing(es, sessionId);
  };

  es.onerror = () => {
    console.log({ isUnloading, readyState: document.readyState });
    if (isUnloading) return;
    sessionStorage.removeItem(SESSION_ID_KEY);
  };

  es.addEventListener("patch", (msg) => {
    prependLog(msg.data);
  });

  es.addEventListener(
    "init",
    (e) => {
      const ids = JSON.parse(e.data) as any;
      const nodeTree = new NodeTree(ids);

      es.addEventListener("patch", (e) => {
        nodeTree.apply(JSON.parse(e.data));
      });
    },
    { once: true }
  );

  const messages = document.createElement("ul");
  document.body.appendChild(messages);

  function prependLog(text: string) {
    const el = document.createElement("li");
    el.textContent = text;
    messages.prepend(el);
  }
}

async function resume(state: string, storedSessionId: string | null) {
  const path = storedSessionId
    ? `/__mayu/api/resume/${storedSessionId}`
    : "/__mayu/api/resume";

  console.log({ storedSessionId });

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

function setupGlobalObject(sessionId: string) {
  const progressBar = document.createElement(
    "mayu-progress-bar"
  ) as MayuProgressBar;

  document.body.appendChild(progressBar);

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

      let didRun = false;
      const timeout = setTimeout(() => {
        progressBar.setAttribute("progress", "25");
        didRun = true;
      }, 1);

      await fetch(`/__mayu/api/callback/${sessionId}/${handlerId}`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      clearTimeout(timeout);

      if (didRun) {
        progressBar.setAttribute("progress", "100");
      }
    },

    async ping() {
      const res = await fetch(`/__mayu/api/callback/${sessionId}/ping`, {
        method: "POST",
        body: JSON.stringify(performance.now()),
      });

      const data = await res.json();
      const latency = performance.now() - data.timestamp;
      const worker = data.worker;

      console.log(
        [
          `Latency: ${latency.toFixed(3)}ms`,
          `Worker: ${worker.toFixed(3)}ms`,
          `Server id: ${data.serverId}`,
          `Server region: ${data.serverRegion}`,
          `Worker id: ${data.workerId}`,
          `Worker region: ${data.workerRegion}`,
          `Routed from: ${data.routedFrom}`,
        ].join("\n")
      );
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
    while (true) {
      try {
        const { ping, region } = await pingTimer.ping((now) => {
          fetch(`/__mayu/api/callback/${sessionId}/ping`, {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify(now),
          });
        });

        pingElement.setAttribute("ping", `${ping} ms`);
        pingElement.setAttribute("region", region);

        await pingTimer.sleep(PingTimer.PING_FREQUENCY_MS);
      } catch (e) {
        console.log(e);
        console.error("Error. Retrying in", PingTimer.RETRY_TIME_MS, "ms");
        await pingTimer.sleep(PingTimer.RETRY_TIME_MS);
      }
    }
  }

  pingLoop();
}
