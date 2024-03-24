const TIMEOUT_MS = 1_000 / 30;

const ThrottledNodes = new WeakMap<EventTarget, ThrottleEntry>();

type ThrottleEntry = {
  timeout: NodeJS.Timeout;
  cb: (() => void) | null;
};

export default function throttle(target: EventTarget, cb: () => void) {
  const entry = ThrottledNodes.get(target);

  if (entry) {
    entry.cb = cb;
    return;
  }

  ThrottledNodes.set(target, {
    timeout: setTimeout(() => {
      const entry = ThrottledNodes.get(target);
      ThrottledNodes.delete(target)
      if (entry) {
        clearTimeout(entry.timeout)
        entry?.cb?.()
      }
    }, TIMEOUT_MS),
    cb: null
  })

  cb();
}
