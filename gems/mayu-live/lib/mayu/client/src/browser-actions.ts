import type { BrowserActionHandler } from "./runtime";

type Navigator = {
  navigate(href: string, pushState?: boolean): void;
};

// Actions a component can run in the browser with `browser.<name>(...)`.
export function createBrowserActionHandler(
  navigator: Navigator,
): BrowserActionHandler {
  const actions: Record<string, (...args: any[]) => void> = {
    navigate(href: string, replace: boolean) {
      navigator.navigate(href, !replace);
    },
    alert(message: string) {
      // alert() blocks, so wait until the DOM updates from the same batch
      // have been painted.
      requestAnimationFrame(() => {
        setTimeout(() => window.alert(message), 0);
      });
    },
  };

  return (name, args) => {
    const action = actions[name];

    if (!action) {
      console.warn(`Unknown browser action: ${name}`);
      return;
    }

    action(...args);
  };
}
