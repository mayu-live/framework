import Outbox from "./connection/outbox";
import SessionConnection from "./connection/session-connection";
import CommandDispatcher from "./dispatch";
import domHandlers from "./dom/handlers";
import NodeRegistry from "./dom/node-registry";
import { createBrowserActionHandler } from "./features/browser-actions";
import Callbacks from "./features/callbacks";
import Heartbeat from "./features/heartbeat";
import type Inspect from "./features/inspect";
import Navigation from "./features/navigation";
import { SESSION_PATH } from "./protocol/constants";
import { errorOverlayHandlers } from "./ui/error-overlay";

let initialized = false;

// Builds the runtime and connects it to the session. This is the only place
// where the modules are wired together: every command is handled by the
// module that owns it, and every event leaves through the outbox.
export default async function init(sessionId: string) {
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

  const outbox = new Outbox();
  const callbacks = new Callbacks(outbox);
  const heartbeat = new Heartbeat(outbox);
  const navigation = new Navigation(outbox);
  const registry = new NodeRegistry((event, listenerId) => {
    callbacks.dispatch(event, listenerId);
  });
  let inspect: Inspect | undefined;

  const connection = new SessionConnection({
    endpoint: `${SESSION_PATH}/${sessionId}`,
    outbox,
    applyBatch: (batch) => dispatcher.applyBatch(batch),
  });

  const dispatcher = new CommandDispatcher({
    ...domHandlers(registry),
    ...callbacks.handlers,
    ...heartbeat.handlers,
    ...navigation.handlers,
    ...connection.handlers,
    ...errorOverlayHandlers,
    BrowserAction: createBrowserActionHandler(navigation),
    InspectResult: (id, result) => inspect?.resolve(id, result),
  });

  dispatcher.onBatchApplied((batch, durationMs) => {
    outbox.recordCommandApply(batch.length, durationMs);
  });

  // The devtools extension defines its hook before the page loads. Without
  // it, none of the devtools code is fetched.
  if (window.__MAYU_DEVTOOLS_HOOK__) {
    const [{ default: Devtools }, { default: Inspect }] = await Promise.all([
      import("./devtools"),
      import("./features/inspect"),
    ]);
    const inspector = new Inspect(outbox);
    inspect = inspector;
    const devtools = new Devtools();
    dispatcher.onBatchApplied((batch, durationMs) => {
      devtools.batchApplied(batch, durationMs);
    });
    devtools.register(
      {
        node: (id) => registry.findNode(id),
        nodeId: (node) => registry.getNodeInfo(node)?.id,
      },
      inspector,
    );
  }

  void connection.run();
}
