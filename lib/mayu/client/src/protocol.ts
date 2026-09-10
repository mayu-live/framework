export type Command = [name: string, ...args: unknown[]];

export type Batch = Command[];

export type CommandErrorPolicy = "continue" | "throw";

export type ClientEvent =
  | [
      name: "Callback",
      listenerId: string,
      event: Record<string, unknown>,
      ping: number,
    ]
  | [name: "Navigate", href: string, pushState: boolean, ping: number]
  | [name: "Ping", ping: number];
