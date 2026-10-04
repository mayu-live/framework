type ViewTransitionStart = (
  update:
    | (() => void | Promise<void>)
    | { update: () => void | Promise<void>; types: string[] },
) => {
  ready?: Promise<void>;
  updateCallbackDone?: Promise<void>;
  finished?: Promise<void>;
} | void;

export type ViewTransitionRoot = {
  startViewTransition?: ViewTransitionStart;
};

function supportsViewTransitionTypes() {
  return (
    typeof CSS !== "undefined" &&
    CSS.supports("selector(:active-view-transition-type(reorder))")
  );
}

export default async function withViewTransition(
  root: ViewTransitionRoot | null,
  update: () => void | Promise<void>,
  types: string[] = [],
) {
  const start = root?.startViewTransition;

  if (!start) {
    await update();
    return;
  }

  const typed = types.length > 0 && supportsViewTransitionTypes();
  const transition = start.call(
    root,
    typed
      ? {
          types,
          update: async () => await update(),
        }
      : update,
  );
  await transition?.updateCallbackDone;
  await transition?.finished;
}
