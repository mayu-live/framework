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
  | [name: "Navigate", id: string, href: string, ping: number]
  | [name: "Ping", ping: number]
  | [name: "Visibility", hidden: boolean, ping: number];
