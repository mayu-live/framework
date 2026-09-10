export type Command = [name: string, ...args: unknown[]];

export type Batch = Command[];

export type CommandErrorPolicy = "continue" | "throw";
