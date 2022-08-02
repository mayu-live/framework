function createSilentLogger() {
  const noop = (..._args: any[]) => {};

  return {
    info: noop,
    log: noop,
    warn: noop,
    error: noop,
    group: noop,
    groupEnd: noop,
  };
}

function createLogger() {
  return {
    info: console.info.bind(console),
    log: console.log.bind(console),
    error: console.error.bind(console),
    warn: console.warn.bind(console),
    group: console.group.bind(console),
    groupEnd: console.groupEnd.bind(console),
  };
}

const SILENT = true

export default SILENT ? createSilentLogger() : createLogger()
