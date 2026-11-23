// The commands the server streams to the browser. Each one is a
// `[name, ...arguments]` tuple, and a batch is an array of them.
//
// client/protocol.json lists the same commands for the server, and
// protocol-manifest.test.ts checks that the two agree.

// The ids of a DOM subtree, in document order. `name` is the node name the
// server expects to find there: "#document", "#text", "#comment" or an
// uppercase tag name.
export type IdNode = {
  id: string;
  name: string;
  children?: IdNode[];
};

export type TreePathEntry = { name: string; path?: string };

export type CommandArguments = {
  Initialize: [tree: IdNode];
  CreateTree: [html: string, trees: IdNode[]];
  ReplaceChildren: [id: string, childIds: string[]];
  RemoveNode: [id: string];
  SetAttribute: [id: string, name: string, value: string];
  RemoveAttribute: [id: string, name: string];
  AddClass: [id: string, classes: string[]];
  RemoveClass: [id: string, classes: string[]];
  SetListener: [id: string, name: string, listenerId: string];
  RemoveListener: [id: string, name: string, listenerId: string];
  SetCSSProperty: [id: string, name: string, value: string];
  RemoveCSSProperty: [id: string, name: string];
  SetTextContent: [id: string, content: string];
  Transfer: [state: Blob];
  TransferFailed: [];
  Pong: [timestamp: number];
  ReloadSucceeded: [];
  NavigationComplete: [id: string];
  NavigationFailed: [id: string];
  DocumentNavigation: [id: string, href: string];
  CallbackComplete: [id: string];
  CallbackFailed: [id: string];
  RegisterCustomElement: [name: string, path: string];
  BrowserAction: [name: string, args: unknown[]];
  ElementCall: [id: string, method: string, args: unknown[]];
  InspectResult: [id: string, result: unknown];
  RenderError: [
    file: string,
    type: string,
    message: string,
    backtrace: string[],
    source: string | null,
    treePath: TreePathEntry[],
    line: number | null,
    column: number | null,
    hints: string[],
  ];
  // Applies the nested batch inside a view transition.
  ViewTransition: [batch: Batch, types?: string[], scope?: string | null];
};

export type CommandName = keyof CommandArguments;

export type Command = {
  [Name in CommandName]: [name: Name, ...args: CommandArguments[Name]];
}[CommandName];

export type Batch = Command[];

export type CommandHandler<Name extends CommandName> = (
  ...args: CommandArguments[Name]
) => void | Promise<void>;

// The handlers for a set of commands. A module declares the commands it owns
// with `CommandHandlers<"Pong" | "Transfer">`.
export type CommandHandlers<Name extends CommandName = CommandName> = {
  [Key in Name]: CommandHandler<Key>;
};
