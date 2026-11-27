import type Outbox from "../connection/outbox";

// A page that still can't apply its commands this soon after getting the
// server's copy has a difference the server can't repair, such as markup
// the browser corrects while parsing. Asking again would only repeat it,
// so from then on the page is left as it is.
const MIN_INTERVAL = 5_000;

// Asks the server for the whole page when a command for the DOM could not
// be applied, which means the page no longer matches what the server
// believes it shows. The server answers with a Resync command.
export default class Resync {
  #outbox: Outbox;
  #pending = false;
  #completedAt = -Infinity;
  #declined = false;

  constructor(outbox: Outbox) {
    this.#outbox = outbox;

    // The request, or its answer, went with the connection. Whatever the
    // next stream starts with, a command that fails after it asks again.
    outbox.onDisconnect(() => {
      this.#pending = false;
    });
  }

  request(reason: string) {
    if (this.#pending || this.#declined) return;

    if (performance.now() - this.#completedAt < MIN_INTERVAL) {
      console.warn(
        "The page still differs from the server right after a resync, so it is left as it is.",
        reason,
      );
      this.#declined = true;
      return;
    }

    this.#pending = true;
    console.warn("Asking the server for the page:", reason);

    void this.#outbox.send(["Resync", reason]).then((wrote) => {
      if (!wrote) this.#pending = false;
    });
  }

  // The server's page has replaced the document.
  completed() {
    this.#pending = false;
    this.#completedAt = performance.now();
  }
}
