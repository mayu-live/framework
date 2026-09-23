import Runtime from "./runtime.js";
import { SESSION_PATH } from "./constants";
import Mayu from "./mayu.js";
import SessionConnection from "./session-connection.js";

let initialized = false;

export default function init(sessionId: string) {
  if (initialized) throw new Error("Mayu is already initialized");
  initialized = true;

  const sheet = new CSSStyleSheet();
  sheet.replaceSync(`
  :root:active-view-transition-type(session-recovery)::view-transition-group(root) {
    animation-duration: var(--mayu-session-recovery-transition-duration, 250ms);
    animation-timing-function: ease-out;
  }
  `);
  document.adoptedStyleSheets.push(sheet);

  const mayu = new Mayu();
  const runtime = new Runtime(
    (event, listenerId) => {
      mayu.callback(event, listenerId);
    },
    {
      onNavigationComplete: (id) => mayu.completeNavigation(id),
      onNavigationFailed: (id) => mayu.failNavigation(id),
      onBatchApplied: (batch, durationMs) =>
        mayu.recordCommandApply(batch.length, durationMs),
    },
  );
  const endpoint = `${SESSION_PATH}/${sessionId}`;
  const connection = new SessionConnection({ runtime, mayu, endpoint });
  void connection.run();
}
