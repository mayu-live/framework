function createSilentLogger() {
  const noop = (..._args: any[]) => {};

  return {
    info: noop,
    log: noop,
    warn: noop,
    error: noop,
    success: noop,
    group: noop,
    groupEnd: noop,
  };
}

function generateStyle(color: string) {
  return [
    `background: ${color}`,
    `border: 1px solid rgba(0, 0, 0, 0.5)`,
    `border-radius: 2px`,
    `padding: 0 2px`,
    `color: #000`,
    `font-weight: bold`,
  ].join(";");
}

function createLogger() {
  return {
    info: console.info.bind(console, "%cinfo", generateStyle("#2196f3")),
    log: console.info.bind(console, "%clog", generateStyle("#ccc")),
    error: console.error.bind(console, "%cerror", generateStyle("#f6685e")),
    warn: console.warn.bind(console, "%cwarn", generateStyle("#ffc107")),
    success: console.info.bind(console, "%csuccess", generateStyle("#a2cf6e")),
    group: console.group.bind(console),
    groupEnd: console.groupEnd.bind(console),
  };
}

const SILENT = false;

export default SILENT ? createSilentLogger() : createLogger();
