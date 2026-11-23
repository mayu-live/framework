import type { Batch, CommandHandlers, CommandName } from "./protocol/commands";
import withViewTransition, {
  type ViewTransitionRoot,
} from "./ui/view-transition";

// What happens after a command fails: the rest of the batch is applied
// anyway, or the batch is abandoned.
export type CommandErrorPolicy = "continue" | "throw";

export const COMMAND_ERROR_POLICY: CommandErrorPolicy = "continue";

// ViewTransition is applied by the dispatcher itself, since it carries a
// batch. TransferFailed never reaches it: the connection ends on it.
export type DispatchedCommandName = Exclude<
  CommandName,
  "ViewTransition" | "TransferFailed"
>;

type BatchListener = (batch: Batch, durationMs: number) => void;

type CommandDispatcherOptions = {
  errorPolicy?: CommandErrorPolicy;
  // Called for every command that could not be applied.
  onCommandFailed?: (name: string, error: unknown) => void;
};

// Applies command batches by calling the handler registered for each
// command, in order, and waits for a handler that returns a promise.
export default class CommandDispatcher {
  #handlers: Record<string, (...args: any[]) => void | Promise<void>>;
  #errorPolicy: CommandErrorPolicy;
  #onCommandFailed?: (name: string, error: unknown) => void;
  #batchListeners = new Set<BatchListener>();

  constructor(
    handlers: CommandHandlers<DispatchedCommandName>,
    {
      errorPolicy = COMMAND_ERROR_POLICY,
      onCommandFailed,
    }: CommandDispatcherOptions = {},
  ) {
    this.#handlers = handlers;
    this.#errorPolicy = errorPolicy;
    this.#onCommandFailed = onCommandFailed;
  }

  // Calls the listener after every batch, with the time it took to apply.
  onBatchApplied(listener: BatchListener) {
    this.#batchListeners.add(listener);
    return () => this.#batchListeners.delete(listener);
  }

  async applyBatch(batch: Batch) {
    const startedAt = performance.now();
    try {
      await this.#apply(batch);
    } finally {
      const durationMs = performance.now() - startedAt;
      for (const listener of this.#batchListeners) listener(batch, durationMs);
    }
  }

  async #apply(batch: Batch) {
    for (const [index, command] of batch.entries()) {
      const [name, ...args] = command;

      try {
        if (command[0] === "ViewTransition") {
          await this.#applyViewTransition(command[1], command[2], command[3]);
          continue;
        }

        if (!Object.hasOwn(this.#handlers, name)) {
          throw new Error(`Unknown command: ${name}`);
        }

        const result = this.#handlers[name](...args);
        if (result instanceof Promise) await result;
      } catch (error) {
        console.error(`Command ${index} (${name}) failed`, error);
        this.#onCommandFailed?.(name, error);
        if (this.#errorPolicy === "throw") throw error;
      }
    }
  }

  #applyViewTransition(
    batch: Batch,
    types: string[] = [],
    scope?: string | null,
  ) {
    const root = (
      scope ? document.getElementById(scope) : document
    ) as ViewTransitionRoot | null;

    return withViewTransition(root, () => this.#apply(batch), types);
  }
}
