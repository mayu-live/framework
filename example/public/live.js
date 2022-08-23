async function resume(state, storedSessionId) {
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

const SESSION_ID_KEY = "mayu.sessionId";

async function init(encryptedState) {
  const sessionId = await resume(
    encryptedState,
    sessionStorage.getItem(SESSION_ID_KEY)
  );

  let isUnloading = false;

  window.addEventListener("beforeunload", () => {
    isUnloading = true;
  });

  const es = new EventSource(`/__mayu/api/events/${sessionId}`);

  es.onopen = () => {
    console.log("Opened session", sessionId);
    sessionStorage.setItem(SESSION_ID_KEY, sessionId);
  };

  es.onerror = () => {
    console.log({ isUnloading, readyState: document.readyState });
    if (isUnloading) return;
    sessionStorage.removeItem(SESSION_ID_KEY);
  };

  es.addEventListener("patch", (msg) => {
    prependLog(msg.data);
  });

  const messages = document.createElement("ul");
  document.body.appendChild(messages);

  function prependLog(text) {
    const el = document.createElement("li");
    el.textContent = text;
    messages.prepend(el);
  }

  window.Mayu = {
    async ping() {
      const res = await fetch(`/__mayu/api/callback/${sessionId}/ping`, {
        method: "POST",
        body: JSON.stringify(performance.now()),
      });

      const data = await res.json();
      const latency = performance.now() - data.timestamp;
      const worker = data.worker;

      prependLog(
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

const uri = new URL(import.meta.url);
const state = uri.hash.slice(1);
init(state);
