import { vi } from "vitest";

import Outbox from "../connection/outbox";
import type { ClientEvent } from "../protocol/events";
import Callbacks from "./callbacks";
import Heartbeat from "./heartbeat";
import Inspect from "./inspect";
import Navigation from "./navigation";

// Test support, not part of the runtime: the features wired to one outbox
// the way main.ts wires them, behind one object, so a test can drive a
// feature and the commands the server would answer it with.
export default class TestClient {
  #outbox = new Outbox();
  #callbacks: Callbacks;
  #heartbeat: Heartbeat;
  #navigation: Navigation;
  #inspect: Inspect;

  constructor({ autoPing = true }: { autoPing?: boolean } = {}) {
    this.#callbacks = new Callbacks(this.#outbox);
    this.#heartbeat = new Heartbeat(this.#outbox, { autoPing });
    this.#navigation = new Navigation(this.#outbox);
    this.#inspect = new Inspect(this.#outbox);
  }

  // The navigation feature itself, for a test that spies on it.
  get navigation() {
    return this.#navigation;
  }

  dispose() {
    this.#navigation.dispose();
    this.#heartbeat.dispose();
    this.#callbacks.dispose();
    this.#inspect.dispose();
  }

  setWriter(writer: WritableStreamDefaultWriter<ClientEvent>) {
    this.#outbox.attach(writer);
  }

  clearWriter() {
    this.#outbox.detach();
  }

  recordCommandApply(commands: number, durationMs: number) {
    this.#outbox.recordCommandApply(commands, durationMs);
  }

  callback(event: Event, listenerId: string) {
    this.#callbacks.dispatch(event, listenerId);
  }

  completeCallback(id: string) {
    void this.#callbacks.handlers.CallbackComplete(id);
  }

  failCallback(id: string) {
    void this.#callbacks.handlers.CallbackFailed(id);
  }

  navigate(href: string, pushState?: boolean, document?: boolean) {
    this.#navigation.navigate(href, pushState, document);
  }

  completeNavigation(id: string) {
    void this.#navigation.handlers.NavigationComplete(id);
  }

  failNavigation(id: string) {
    void this.#navigation.handlers.NavigationFailed(id);
  }

  documentNavigation(id: string, href: string) {
    void this.#navigation.handlers.DocumentNavigation(id, href);
  }

  ping() {
    this.#heartbeat.ping();
  }

  inspect(query: Record<string, unknown>) {
    return this.#inspect.inspect(query);
  }

  resolveInspect(id: string, result: unknown) {
    this.#inspect.resolve(id, result);
  }
}

// A stand-in for the Navigation API, which jsdom does not have.
export class FakeNavigation extends EventTarget {
  navigate = vi.fn();
}

export function navigationEvent(
  overrides: Partial<Record<string, unknown>> = {},
) {
  const event = new Event("navigate") as Event & Record<string, unknown>;
  Object.assign(event, {
    canIntercept: true,
    destination: { url: new URL("/next?tab=details", location.origin).href },
    downloadRequest: null,
    formData: null,
    hashChange: false,
    navigationType: "push",
    signal: new AbortController().signal,
    intercept: vi.fn(),
    ...overrides,
  });
  return event;
}
