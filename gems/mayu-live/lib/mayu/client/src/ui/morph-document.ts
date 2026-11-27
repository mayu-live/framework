import morphdom from "morphdom";

// Changes the document into the one the HTML describes, keeping the nodes
// the two have in common. This module is loaded on demand, and morphdom with
// it: a healthy session never needs either.
//
// The error overlay is put there by the runtime, not by the server. It
// stays when the page is brought back in line with its session, and goes
// when the session is replaced: an error of the old one says nothing about
// the new one.
export default function morphDocument(html: string, keepErrorOverlay = false) {
  const restore: Array<() => void> = [];

  morphdom(document.documentElement, html.replace(/^<!DOCTYPE html>\n/, ""), {
    // The status indicator shows the state of this page's connection, which
    // the server's copy knows nothing about.
    onBeforeElUpdated: (from, to) => {
      if (from.localName === "mayu-ping") return false;
      keepUserInput(from, to, restore);
      return true;
    },
    onBeforeNodeDiscarded: (node) =>
      !(
        keepErrorOverlay &&
        node instanceof Element &&
        node.localName === "mayu-exception"
      ),
  });

  for (const put of restore) put();

  // Only the property shows, and morphdom brings over only the attribute.
  for (const input of document.querySelectorAll("input")) {
    input.indeterminate = input.hasAttribute("indeterminate");
  }
}

// What the user has typed, ticked or chosen is not in the server's page
// unless a listener sent it there. A field's default is what the server
// last said about it, so where the server's page has the same default, the
// server has nothing new to say and the field keeps what the user gave it.
// morphdom overwrites it, so it is put back afterwards.
function keepUserInput(from: Element, to: Element, restore: Array<() => void>) {
  if (from instanceof HTMLInputElement && to instanceof HTMLInputElement) {
    const { value, checked } = from;
    // The value of a file input can't be set.
    if (from.type !== "file" && from.defaultValue === to.defaultValue) {
      restore.push(() => (from.value = value));
    }
    if (from.defaultChecked === to.defaultChecked) {
      restore.push(() => (from.checked = checked));
    }
  } else if (
    from instanceof HTMLTextAreaElement &&
    to instanceof HTMLTextAreaElement
  ) {
    const { value } = from;
    if (from.defaultValue === to.defaultValue) {
      restore.push(() => (from.value = value));
    }
  } else if (
    from instanceof HTMLSelectElement &&
    to instanceof HTMLSelectElement
  ) {
    // morphdom clears the selection at the first option it reaches, so
    // it is read here, before any of them.
    const options = [...from.options];
    const defaults = (select: HTMLSelectElement) =>
      Array.from(select.options, (option) => option.defaultSelected).join();
    const selected = options.map((option) => option.selected);
    if (defaults(from) === defaults(to)) {
      restore.push(() =>
        options.forEach((option, i) => (option.selected = selected[i])),
      );
    }
  }
}
