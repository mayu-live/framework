import logger from "./logger.js";
import NodeTree from "./NodeTree.js";
import PingTimer from "./PingTimer.js";
import PingComponent from "./PingComponent.js";
import DisconnectedComponent from "./DisconnectedComponent.js";

window.customElements.define("mayu-disconnected", DisconnectedComponent);
window.customElements.define("mayu-ping", PingComponent);


// TODO: Make more of this set up stuff in a functional way.
class Mayu {
  readonly sessionId: string;
  readonly connection: EventSource;
  readonly queue = <MessageEvent[]>[];

  constructor(sessionId: string) {
    this.sessionId = sessionId;

    this.connection = new EventSource(`/__mayu/events/${this.sessionId}`);

    const disconnectedElement = document.createElement("mayu-disconnected");

    this.connection.onopen = () => {
      console.log("Connection opened");
      document.body
        .querySelectorAll("mayu-disconnected")
        .forEach((el) => el.remove());
    };

    this.connection.onerror = (e) => {
      logger.log(e);
      logger.error("Connection error.");
      document.body.appendChild(disconnectedElement);
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
      window.navigation.addEventListener("navigate", (e: NavigateEvent) => {
        // console.log(e);
        // e.preventDefault()
      });
    }

    this.connection.addEventListener("navigate", (e) => {
      const path = JSON.parse(e.data);
      console.log("Navigating to", path);
      history.pushState({}, "", path);
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

    const pingElement = document.createElement('mayu-ping') as PingComponent;
    document.body.appendChild(pingElement);

    async function pingLoop() {
      while (true) {
        try {
          const { ping, region } = await pingTimer.ping((now) => {
            fetch(`/__mayu/handler/${sessionId}/ping`, {
              method: "POST",
              headers: { "content-type": "application/json" },
              body: JSON.stringify(now),
            });
          });

          pingElement.setAttribute('ping', `${ping} ms`)
          pingElement.setAttribute('region', region)

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
