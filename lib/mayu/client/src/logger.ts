export function createSilentLogger() {
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

export function createLogger(prefix = "mayu/") {
  return {
    info: console.info.bind(
      console,
      `%c${prefix}info`,
      generateStyle("#35baf6")
    ),
    log: console.info.bind(console, `%c${prefix}log`, generateStyle("#ccc")),
    error: console.error.bind(
      console,
      `%c${prefix}error`,
      generateStyle("#f6685e")
    ),
    warn: console.warn.bind(
      console,
      `%c${prefix}warn`,
      generateStyle("#ffc107")
    ),
    success: console.info.bind(
      console,
      `%c${prefix}success`,
      generateStyle("#a2cf6e")
    ),
    group: console.group.bind(console),
    groupEnd: console.groupEnd.bind(console),
  };
}

const SILENT = false;

export default SILENT ? createSilentLogger() : createLogger();
