import type Mayu from "./Mayu.js";

declare global {
  interface Node {
    __MAYU_ID: number;
  }

  interface Navigation extends EventTarget {}

  interface NavigateEvent extends Event {
    transitionWhile: (promise: Promise<any>) => void;
  }

  interface Window {
    Mayu: Mayu;
    navigation?: Navigation;
  }

  class DecompressionStream extends TransformStream<Uint8Array, Uint8Array> {
    constructor(format: string);
  }

  interface Document {
    adoptedStyleSheets: any[];
  }
}
