import type { CommandHandlers } from "../protocol/commands";

// The overlay and its custom element are only fetched when an error
// actually arrives. A production server never sends one, so a production
// page never loads them.
export const errorOverlayHandlers: CommandHandlers<
  "RenderError" | "ReloadSucceeded"
> = {
  async RenderError(...args) {
    const { default: renderError, fromCommand } =
      await import("./render-error");
    renderError(fromCommand(args));
  },
  ReloadSucceeded() {
    document.querySelectorAll("mayu-exception").forEach((e) => e.remove());
  },
};
