// This module imports nothing. A module it shared with the rest of the
// runtime would be bundled into this file, and the runtime would import
// this file again under a URL without the session id, running it twice.
// protocol-manifest.test.ts holds the values below to protocol/constants.ts.

const sessionId = new URL(import.meta.url).hash.slice(1);

if (!sessionId) {
  throw new Error("Mayu: the runtime was loaded without a session id");
}

// The command stream needs nothing but the session id, so the request for
// it goes out now, while the rest of the runtime is still on its way. The
// runtime reads the response as that of its first connection.
const controller = new AbortController();
const response = fetch(`/.mayu/session/${sessionId}`, {
  credentials: "include",
  cache: "no-store",
  signal: controller.signal,
  headers: {
    accept: "application/vnd.mayu.event-stream",
    "mayu-protocol": "2",
  },
});
// The runtime handles a failure when it reads the response.
response.catch(() => undefined);

const startRuntime = async () => {
  const { default: init } = await import("./main");
  await init(sessionId, { response, controller });
};
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", startRuntime, { once: true });
} else {
  void startRuntime();
}
