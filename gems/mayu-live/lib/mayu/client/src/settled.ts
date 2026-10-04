// Lets code that dispatches an event wait for the Mayu handlers it reached:
//
//   this.dispatchEvent(event);
//   await settled(event);
//
// The runtime stores one promise per handler call on the event, under a
// global symbol. App modules import their own copy of `settled` from
// virtual:mayu/client (see mayu-build), and the symbol lets that copy find
// the promises without access to the runtime instance.
export const SETTLED = Symbol.for("mayu.settled");

type SettledEvent = Event & { [SETTLED]?: Promise<void>[] };

export function attachSettlement(event: Event, promise: Promise<void>) {
  // Nobody has to wait for a handler, so a failure is not an unhandled
  // rejection. `settled` still rejects with it.
  promise.catch(() => {});
  ((event as SettledEvent)[SETTLED] ??= []).push(promise);
}

// Resolves once every Mayu handler the event reached has returned and the
// updates it made are applied, or right away if it reached none. Rejects if
// a handler raised, its component went away, or the connection dropped.
export function settled(event: Event): Promise<void> {
  return Promise.all((event as SettledEvent)[SETTLED] ?? []).then(() => {});
}
