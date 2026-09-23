const sessionId = new URL(import.meta.url).hash.slice(1);

const startRuntime = async () => {
  const { default: init } = await import("./main");
  init(sessionId);
};
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", startRuntime, { once: true });
} else {
  void startRuntime();
}
