import logger from "./logger.js";
import NodeTree from "./NodeTree.js";
import type { Patch } from "./NodeTree.js";

class Mayu {
  readonly sessionId: string;
  readonly connection: EventSource;
  readonly queue = <MessageEvent[]>[];

  constructor(sessionId: string) {
    this.sessionId = sessionId;
    this._updateHTML = this._updateHTML.bind(this);

    this.connection = new EventSource(`/__mayu/events/${this.sessionId}`);

    this.connection.onerror = (e) => {
      logger.log(e);
      logger.error("Connection error.");
    };

    this.connection.addEventListener(
      "patch",
      (e) => {
        const [firstPatch, ...rest] = JSON.parse(e.data).patches as Patch[]

        const nodeTree = new NodeTree((firstPatch as any).ids);
        nodeTree.apply(rest);

        this.connection.addEventListener("patch", (e) => {
          nodeTree.apply(JSON.parse(e.data).patches);
        });
      },
      { once: true }
    );
  }

  handle(e: Event, handlerId: string) {
    e.preventDefault();

    const payload = {
      type: e.type,
      value: (e.target as any).value,
    } as Record<string, any>;

    if (e.target instanceof HTMLFormElement) {
      payload.formData = Object.fromEntries(new FormData(e.target).entries());
    }

    fetch(`/__mayu/handler/${this.sessionId}/${handlerId}`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    });
  }

  _updateHTML({ data }: MessageEvent) {
    const html = JSON.parse(data)
      .replace(/^<html.*?>/, "")
      .replace(/<\/html>$/, "");
    document.documentElement.innerHTML = html;
  }
}

export default Mayu;
