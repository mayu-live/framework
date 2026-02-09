import Runtime from "./runtime.js";
import { SESSION_PATH } from "./constants";
import Mayu from "./mayu.js";
import SessionConnection from "./session-connection.js";

import "./custom-elements/mayu-exception";

declare global {
  interface Window {
    Mayu: Mayu;
  }
}

export default function init(sessionId: string) {
  if (window.Mayu) {
    console.error(
      "%cwindow.Mayu is already defined",
      "font-size: 1.5em; color: #c00;"
    );
    throw "window.Mayu is already defined";
  }

  const sheet = new CSSStyleSheet();
  sheet.replaceSync(`
  ::view-transition-old(root),
  ::view-transition-new(root) {
    animation-duration: 1s;
  }
  `);
  document.adoptedStyleSheets.push(sheet);

  const runtime = new Runtime();
  const mayu = new Mayu();
  window.Mayu = mayu;

  const endpoint = `${SESSION_PATH}/${sessionId}`;
  const connection = new SessionConnection({ runtime, mayu, endpoint });
  void connection.run();
}
