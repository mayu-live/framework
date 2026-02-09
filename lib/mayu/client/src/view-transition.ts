type DocumentWithViewTransition = Document & {
  startViewTransition?: (
    update: () => void | Promise<void>
  ) => { updateCallbackDone?: Promise<void> } | void;
};

export default async function withViewTransition(
  update: () => void | Promise<void>
) {
  const start = (document as DocumentWithViewTransition).startViewTransition;

  if (!start) {
    await update();
    return;
  }

  const transition = start.call(document, update);
  await transition?.updateCallbackDone;
}
