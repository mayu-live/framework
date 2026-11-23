import CommandDispatcher, { type CommandErrorPolicy } from "./dispatch";
import domHandlers from "./dom/handlers";
import NodeRegistry from "./dom/node-registry";
import type { Batch } from "./protocol/commands";
import { errorOverlayHandlers } from "./ui/error-overlay";
import { updatePing } from "./ui/status";

type TestRuntimeOptions = {
  commandErrorPolicy?: CommandErrorPolicy;
  onNavigationComplete?: (id: string) => void;
  onNavigationFailed?: (id: string) => void;
  onDocumentNavigation?: (id: string, href: string) => void;
  onBrowserAction?: (name: string, args: unknown[]) => void;
  onBatchApplied?: (batch: Batch, durationMs: number) => void;
  onInspectResult?: (id: string, result: unknown) => void;
  onCallbackComplete?: (id: string) => void;
  onCallbackFailed?: (id: string) => void;
};

// Test support, not part of the runtime: a dispatcher with the DOM handlers
// and a node registry, the way main.ts wires them. The commands that belong
// to a feature call the given function instead.
export default class TestRuntime {
  #registry: NodeRegistry;
  #dispatcher: CommandDispatcher;

  constructor(
    onEvent: (event: Event, listenerId: string) => void,
    options: TestRuntimeOptions = {},
  ) {
    this.#registry = new NodeRegistry(onEvent);
    this.#dispatcher = new CommandDispatcher(
      {
        ...domHandlers(this.#registry),
        ...errorOverlayHandlers,
        NavigationComplete: (id) => options.onNavigationComplete?.(id),
        NavigationFailed: (id) => options.onNavigationFailed?.(id),
        DocumentNavigation: (id, href) =>
          options.onDocumentNavigation?.(id, href),
        BrowserAction: (name, args) => options.onBrowserAction?.(name, args),
        InspectResult: (id, result) => options.onInspectResult?.(id, result),
        CallbackComplete: (id) => options.onCallbackComplete?.(id),
        CallbackFailed: (id) => options.onCallbackFailed?.(id),
        Pong: (timestamp) => updatePing(performance.now() - timestamp),
        Transfer: () => undefined,
      },
      { errorPolicy: options.commandErrorPolicy },
    );

    if (options.onBatchApplied) {
      this.#dispatcher.onBatchApplied(options.onBatchApplied);
    }
  }

  applyBatch(batch: Batch) {
    return this.#dispatcher.applyBatch(batch);
  }

  node(id: string): Node | undefined {
    return this.#registry.findNode(id);
  }

  nodeId(node: Node): string | undefined {
    return this.#registry.getNodeInfo(node)?.id;
  }
}
