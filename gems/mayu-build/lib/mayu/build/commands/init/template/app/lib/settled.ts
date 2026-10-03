// Waits for the Mayu handlers an event reached, for custom elements that
// dispatch events to the page:
//
//   this.dispatchEvent(event);
//   await settled(event);
//
// Resolves once every handler has returned and the updates it made are
// applied, or right away if the event reached none. Rejects if a handler
// raised, its component went away, or the connection dropped. The Mayu
// runtime stores its promises on the event under this global symbol.
const SETTLED = Symbol.for("mayu.settled");

export function settled(event: Event): Promise<void> {
  const promises: Promise<void>[] =
    (event as Event & { [SETTLED]?: Promise<void>[] })[SETTLED] ?? [];
  return Promise.all(promises).then(() => {});
}
