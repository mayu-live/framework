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
  morphdom(document.documentElement, html.replace(/^<!DOCTYPE html>\n/, ""), {
    // The status indicator shows the state of this page's connection, which
    // the server's copy knows nothing about.
    onBeforeElUpdated: (from) => from.localName !== "mayu-ping",
    onBeforeNodeDiscarded: (node) =>
      !(
        keepErrorOverlay &&
        node instanceof Element &&
        node.localName === "mayu-exception"
      ),
  });

  // Only the property shows, and morphdom brings over only the attribute.
  for (const input of document.querySelectorAll("input")) {
    input.indeterminate = input.hasAttribute("indeterminate");
  }
}
