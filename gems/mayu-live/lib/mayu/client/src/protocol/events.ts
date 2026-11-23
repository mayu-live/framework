// The events the browser sends to the server.
//
// On the wire every event is `[name, ping, ack, telemetry, ...arguments]`.
// `ping` is performance.now() at the time of sending, which the server echoes
// back in a Pong. `ack` is null, or the number of the last batch the browser
// applied. `telemetry` is null, or how long the browser spent applying
// command batches since its last event.

export type CommandApplyTelemetry = {
  batches: number;
  commands: number;
  duration_ms: number;
};

// An event as a feature hands it to the outbox: its name and arguments.
// A callback with a settle id is answered with CallbackComplete or
// CallbackFailed; one without is not.
export type OutboundEvent =
  | [name: "Callback", listenerId: string, event: Record<string, unknown>]
  | [
      name: "Callback",
      listenerId: string,
      event: Record<string, unknown>,
      settleId: string,
    ]
  | [name: "Navigate", id: string, href: string]
  | [name: "Ping"]
  | [name: "Visibility", hidden: boolean]
  | [name: "Inspect", id: string, query: Record<string, unknown>]
  // Asks for the whole page, after a command could not be applied.
  | [name: "Resync", reason: string];

type Framed<Event> = Event extends [infer Name, ...infer Arguments]
  ? [
      name: Name,
      ping: number,
      ack: number | null,
      telemetry: CommandApplyTelemetry | null,
      ...args: Arguments,
    ]
  : never;

// An event on the wire. The outbox adds the header.
export type ClientEvent = Framed<OutboundEvent>;
