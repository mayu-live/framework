export type Command = [name: string, ...args: unknown[]];

export type Batch = Command[];

export type CommandErrorPolicy = "continue" | "throw";

export type CommandApplyTelemetry = {
  batches: number;
  commands: number;
  duration_ms: number;
};

export type ClientEvent =
  | [
      name: "Callback",
      listenerId: string,
      event: Record<string, unknown>,
      ping: number,
      telemetry?: CommandApplyTelemetry,
    ]
  | [
      name: "Navigate",
      id: string,
      href: string,
      ping: number,
      telemetry?: CommandApplyTelemetry,
    ]
  | [name: "Ping", ping: number, telemetry?: CommandApplyTelemetry]
  | [
      name: "Visibility",
      hidden: boolean,
      ping: number,
      telemetry?: CommandApplyTelemetry,
    ];
