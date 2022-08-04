import logger from "./logger.js";
import NodeTree from "./NodeTree.js";
import PingTimer from "./PingTimer.js";
import DisconnectedComponent from './DisconnectedComponent.js'

window.customElements.define('mayu-disconnected', DisconnectedComponent);

class PingView {
  div: HTMLDivElement;

  constructor() {
    const div = document.createElement("div");
    div.style.setProperty("position", "fixed");
    div.style.setProperty("bottom", "0");
    div.style.setProperty("left", "0");
    div.style.setProperty("z-index", "10");
    div.style.setProperty("backdrop-filter", "blur(5px)");
    div.style.setProperty("border", "0 solid #0003");
    div.style.setProperty("border-width", "1px 1px 0 0");
    div.style.setProperty("font-size", ".9em");
    div.style.setProperty("padding", ".2em .5em");
    div.style.setProperty("border-top-right-radius", "3px");
    div.style.setProperty("pointer-events", "none");
    div.style.setProperty(
      "text-shadow",
      Array(10).fill("0 0 2px #000").join(",")
    );
    div.style.setProperty("color", "#fff");
    div.style.setProperty("font-weight", "bold");
    div.style.setProperty("font-family", "monospace");
    div.querySelector("::before");
    document.body.appendChild(div);

    this.div = div;
  }

  update(text: string) {
    this.div.textContent = text;
  }
}

// TODO: Make more of this set up stuff in a functional way.
class Mayu {
  readonly sessionId: string;
  readonly connection: EventSource;
  readonly queue = <MessageEvent[]>[];

  constructor(sessionId: string) {
    this.sessionId = sessionId;

    this.connection = new EventSource(`/__mayu/events/${this.sessionId}`);

    const disconnectedElement = document.createElement('mayu-disconnected');

    this.connection.onopen = () => {
      console.log('Connection opened')
      document.body.querySelectorAll('mayu-disconnected').forEach((el) => el.remove())
    }

    this.connection.onerror = (e) => {
      logger.log(e);
      logger.error("Connection error.");
      document.body.appendChild(disconnectedElement)
    };

    this.connection.addEventListener(
      "init",
      (e) => {
        const ids = JSON.parse(e.data) as any;
        const nodeTree = new NodeTree(ids);

        this.connection.addEventListener("patch", (e) => {
          nodeTree.apply(JSON.parse(e.data));
        });
      },
      { once: true }
    );

    if (window.navigation) {
      window.navigation.addEventListener('navigate', (e: NavigateEvent) => {
        console.log(e)
        // e.preventDefault()
      });
    }

    this.connection.addEventListener("navigate", (e) => {
      const path = JSON.parse(e.data)
      console.log('Navigating to', path)
      history.pushState({}, '', path)
    });

    // if ("serviceWorker" in navigator) {
    //   navigator.serviceWorker
    //     .register("/__mayu.serviceWorker.js", { scope: "/" })
    //     .then((reg) => {
    //       console.log("Registration Successful", reg);
    //       reg?.active?.postMessage({ type: "sessionId", sessionId });
    //
    //       window.addEventListener("beforeunload", () => {
    //         reg?.active?.postMessage({ type: "closeWindow", sessionId });
    //       });
    //     })
    //     .catch((e) => console.error(e));
    // }

    const pingTimer = new PingTimer();

    this.connection.addEventListener("pong", (e) => {
      pingTimer.pong(JSON.parse(e.data));
    });

    const pingView = new PingView();

    async function pingLoop() {
      while (true) {
        try {
          const pingTime = await pingTimer.ping((now) => {
            fetch(`/__mayu/handler/${sessionId}/ping`, {
              method: "POST",
              headers: { "content-type": "application/json" },
              body: JSON.stringify(now),
            });
          });

          pingView.update(`Ping: ${pingTime} ms`);
          await pingTimer.sleep(PingTimer.PING_FREQUENCY_MS);
        } catch (e) {
          console.error("Error. Retrying in", PingTimer.RETRY_TIME_MS, "ms");
          await pingTimer.sleep(PingTimer.RETRY_TIME_MS);
        }
      }
    }

    pingLoop();

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

  async #ping() {}
}

export default Mayu;
