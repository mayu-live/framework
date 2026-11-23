import type {
  ClientEvent,
  CommandApplyTelemetry,
  OutboundEvent,
} from "../protocol/events";

type Listener = () => void;

// The one place events leave the browser from. The connection attaches a
// writer while it has a stream to the server and detaches it when the
// stream ends. Events sent in between are dropped, never replayed, and the
// features that wait for an answer hear about it through onDisconnect.
export default class Outbox {
  #writer: WritableStreamDefaultWriter<ClientEvent> | null = null;
  #telemetry: CommandApplyTelemetry = emptyTelemetry();
  #connectListeners = new Set<Listener>();
  #disconnectListeners = new Set<Listener>();
  #sendListeners = new Set<Listener>();

  get connected() {
    return this.#writer !== null;
  }

  onConnect(listener: Listener) {
    this.#connectListeners.add(listener);
  }

  // Also called when a connection attempt ends without ever attaching.
  onDisconnect(listener: Listener) {
    this.#disconnectListeners.add(listener);
  }

  // Called after every event that was written.
  onSend(listener: Listener) {
    this.#sendListeners.add(listener);
  }

  attach(writer: WritableStreamDefaultWriter<ClientEvent>) {
    this.#writer = writer;
    for (const listener of this.#connectListeners) listener();
  }

  detach() {
    this.#writer = null;
    for (const listener of this.#disconnectListeners) listener();
  }

  // The time spent applying commands rides along with the next event.
  recordCommandApply(commands: number, durationMs: number) {
    this.#telemetry.batches += 1;
    this.#telemetry.commands += commands;
    this.#telemetry.duration_ms += durationMs;
  }

  // Resolves to whether the event was written.
  async send(message: OutboundEvent): Promise<boolean> {
    const eventName = message[0].toLowerCase();
    const writer = this.#writer;
    if (!writer) {
      console.warn(`Dropping ${eventName}: callback transport unavailable`);
      return false;
    }

    const [name, ...args] = message;
    const telemetry = this.#takeTelemetry();
    const event = [name, performance.now(), telemetry, ...args] as ClientEvent;

    try {
      await writer.write(event);
      for (const listener of this.#sendListeners) listener();
      return true;
    } catch (error) {
      if (telemetry) this.#restoreTelemetry(telemetry);
      if (this.#writer === writer) this.detach();
      console.error(`Dropping ${eventName}: callback write failed`, error);
      return false;
    }
  }

  #takeTelemetry() {
    if (this.#telemetry.batches === 0) return null;

    const telemetry = this.#telemetry;
    this.#telemetry = emptyTelemetry();
    return telemetry;
  }

  #restoreTelemetry(telemetry: CommandApplyTelemetry) {
    this.#telemetry.batches += telemetry.batches;
    this.#telemetry.commands += telemetry.commands;
    this.#telemetry.duration_ms += telemetry.duration_ms;
  }
}

function emptyTelemetry(): CommandApplyTelemetry {
  return { batches: 0, commands: 0, duration_ms: 0 };
}
