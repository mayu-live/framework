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
import type Resync from "./features/resync";
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
  // Loaded when a command first fails, which a healthy page never sees.
  let resync: Promise<Resync> | undefined;
  const withResync = (use: (resync: Resync) => void) => {
    resync ??= import("./features/resync").then(
      ({ default: Resync }) => new Resync(outbox),
    );
    resync.then(use, (error) => {
      // Try the import again the next time.
      resync = undefined;
      console.error(error);
    });
  };
  const registry = new NodeRegistry((event, listenerId) => {
    callbacks.dispatch(event, listenerId);
  });
  let inspect: Inspect | undefined;

  const connection = new SessionConnection({
    endpoint: `${SESSION_PATH}/${sessionId}`,
    outbox,
    applyBatch: (batch) => dispatcher.applyBatch(batch),
  });

  const dom = domHandlers(registry, {
    // Noted even when the page never asked, so that a page which still
    // differs after it does not ask for it over and over.
    onResynced: () => withResync((resync) => resync.completed()),
  });

  const dispatcher = new CommandDispatcher(
    {
      ...dom,
      ...callbacks.handlers,
      ...heartbeat.handlers,
      ...navigation.handlers,
      ...connection.handlers,
      ...errorOverlayHandlers,
      BrowserAction: createBrowserActionHandler(navigation),
      InspectResult: (id, result) => inspect?.resolve(id, result),
    },
    {
      // A DOM command that fails means the page is not what the server
      // thinks it is. The rest of the batch is still applied, and the
      // server's copy of the page replaces whatever that leaves behind.
      onCommandFailed: (name, error) => {
        if (Object.hasOwn(dom, name)) {
          const message =
            error instanceof Error ? error.message : String(error);
          withResync((resync) => resync.request(`${name}: ${message}`));
        }
      },
    },
  );

  dispatcher.onBatchApplied((batch, durationMs) => {
    outbox.recordCommandApply(batch.length, durationMs);
  });

  // The devtools extension defines its hook before the page loads. Without
  // it, none of the devtools code is fetched.
  if (window.__MAYU_DEVTOOLS_HOOK__) {
    // The page works without them.
    await connectDevtools().catch(console.error);
  }

  void connection.run();

  async function connectDevtools() {
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
}
