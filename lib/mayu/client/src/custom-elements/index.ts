function load() {
  return Promise.all([
    import("./mayu-ping"),
    import("./mayu-disconnected"),
    import("./mayu-progress-bar"),
    import("./mayu-exception"),
  ]);
}

export default load();
