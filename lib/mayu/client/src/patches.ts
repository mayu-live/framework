export default interface Patches {
  Initialize(idTree: any): void;

  CreateTree(html: string, tree: any): void;

  CreateElement(id: string, type: string): void;
  CreateTextNode(id: string, content: string): void;
  CreateComment(id: string, content: string): void;

  ReplaceChildren(id: string, childIds: string[]): void;

  RemoveNode(id: string): void;

  SetAttribute(id: string, name: string, value: string): void;
  RemoveAttribute(id: string, name: string): void;

  SetClassName(id: string, className: string): void;

  SetListener(id: string, name: string, listenerId: string): void;
  RemoveListener(id: string, name: string, listenerId: string): void;

  SetCSSProperty(id: string, name: string, value: string): void;
  RemoveCSSProperty(id: string, name: string): void;

  SetTextContent(id: string, content: string): void;
  ReplaceData(id: string, offset: number, count: number, data: string): void;
  InsertData(id: string, offset: number, data: string): void;
  DeleteData(id: string, offset: number, count: number): void;

  AddStyleSheet(filename: string): void;

  Transfer(payload: Blob): void;

  Ping(timestamp: number): void;
  Pong(timestamp: number): void;

  Event(event: string, payload: any): void;
  HistoryPushState(path: string): void;

  RenderError(file: string, type: string, message: string, backtrace: string[], source: string, treePath: any): void;
};