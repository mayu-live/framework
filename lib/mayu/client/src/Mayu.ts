import logger from "./logger.js";
import NodeTree from "./NodeTree.js";

class PingView {
  div: HTMLDivElement;

  constructor() {
    const div = document.createElement('div')
    div.style.setProperty('position', 'fixed')
    div.style.setProperty('bottom', '0')
    div.style.setProperty('left', '0')
    div.style.setProperty('z-index', '10')
    div.style.setProperty('backdrop-filter', 'blur(5px)')
    div.style.setProperty('border', '0 solid #0003')
    div.style.setProperty('border-width', '1px 1px 0 0')
    div.style.setProperty('font-size', '.9em')
    div.style.setProperty('padding', '.2em .5em')
    div.style.setProperty('border-top-right-radius', '3px')
    div.style.setProperty('pointer-events', 'none')
    div.style.setProperty('text-shadow', Array(10).fill('0 0 2px #000').join(','))
    div.style.setProperty('color', '#fff')
    div.style.setProperty('font-weight', 'bold')
    div.style.setProperty('font-family', 'monospace')
    div.querySelector("::before")
    document.body.appendChild(div)

    this.div = div
  }

  update(text: string) {
    this.div.textContent = text
  }
}

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

    const pingView = new PingView()
    this.connection.addEventListener('pong', (e) => {
      const time = JSON.parse(e.data);
      const delta = new Date().getTime() - time;
      pingView.update(`Ping: ${delta} ms`)
    })

    this.#ping();
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

  async #ping() {
    await fetch(`/__mayu/handler/${this.sessionId}/ping`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(new Date().getTime()),
    });

    setTimeout(() => this.#ping(), 3000)
  }
}

export default Mayu;
