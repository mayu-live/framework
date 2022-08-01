import logger from './logger.js'
import NodeTree from './NodeTree.js'
import type { IdNode, Patch } from './NodeTree.js'

class Mayu {
  readonly sessionId: string;
  readonly connection: EventSource;
  readonly nodeTree: NodeTree;
  readonly queue = <MessageEvent[]>[];

  constructor(sessionId: string, idTreeRoot: IdNode) {
    this.sessionId = sessionId;
    this._updateHTML = this._updateHTML.bind(this);
    this.nodeTree = new NodeTree(idTreeRoot);

    this.connection = new EventSource(`/__mayu/events/${this.sessionId}`);

    this.connection.onerror = (e) => {
      logger.log(e);
      logger.error("Connection error.");
    };

    // this.connection.addEventListener("html", this._updateHTML);
    this.connection.addEventListener("patch_set", (e) => {
      logger.log('GOT PATCHES', e.data)
      this.#applyPatches(e);
    });
  }

  handle(e: Event, handlerId: string) {
    e.preventDefault();

    const payload = {
      type: e.type,
      value: (e.target as any).value,
    };

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

  #applyPatches({ data }: MessageEvent) {
    logger.info("APPLYING PATCHES");
    const { patches } = JSON.parse(data) as { patches: Patch[] };

    this.nodeTree.apply(patches)
  }
}

export default Mayu;
