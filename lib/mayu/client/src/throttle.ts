const TIMEOUT_MS = 1_000 / 30;

const ThrottledNodes = new WeakMap<EventTarget, Map<string, ThrottleEntry>>();

type ThrottleEntry = {
  timeout: number;
  cb: (() => void) | null;
};

export default function throttle(
  target: EventTarget,
  key: string,
  cb: () => void,
) {
  let entries = ThrottledNodes.get(target);
  if (!entries) {
    entries = new Map();
    ThrottledNodes.set(target, entries);
  }

  const entry = entries.get(key);

  if (entry) {
    entry.cb = cb;
    return;
  }

  entries.set(key, {
    timeout: setTimeout(() => {
      const targetEntries = ThrottledNodes.get(target);
      const entry = targetEntries?.get(key);
      targetEntries?.delete(key);
      if (targetEntries?.size === 0) ThrottledNodes.delete(target);
      if (entry) {
        clearTimeout(entry.timeout);
        entry.cb?.();
      }
    }, TIMEOUT_MS),
    cb: null,
  });

  cb();
}
