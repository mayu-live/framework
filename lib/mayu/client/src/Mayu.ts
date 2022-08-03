import logger from "./logger.js";
import NodeTree from "./NodeTree.js";

class Mayu {
  readonly sessionId: string;
  readonly connection: EventSource;
  readonly queue = <MessageEvent[]>[];

  constructor(sessionId: string) {
    this.sessionId = sessionId;

    this.connection = new EventSource(`/__mayu/events/${this.sessionId}`);

    this.connection.onerror = (e) => {
      logger.log(e);
      logger.error("Connection error.");
    };

    this.connection.addEventListener(
      "init",
      (e) => {
        const ids = (JSON.parse(e.data) as any);
        const nodeTree = new NodeTree(ids)

        this.connection.addEventListener("patch", (e) => {
          nodeTree.apply(JSON.parse(e.data));
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
}

export default Mayu;
