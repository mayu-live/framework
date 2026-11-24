import morphdom from "morphdom";

// Changes the document into the one the HTML describes, keeping the nodes
// the two have in common. This module is loaded on demand, and morphdom with
// it: a healthy session never needs either.
export default function morphDocument(html: string) {
  morphdom(document.documentElement, html.replace(/^<!DOCTYPE html>\n/, ""), {
    // The status indicator shows the state of this page's connection, which
    // the server's copy knows nothing about.
    onBeforeElUpdated: (from) => from.localName !== "mayu-ping",
    // The error overlay is put there by the runtime, not by the server.
    onBeforeNodeDiscarded: (node) =>
      !(node instanceof Element && node.localName === "mayu-exception"),
  });
}
