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

  interface Document {
    adoptedStyleSheets: any[];
  }
}
