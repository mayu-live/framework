import { sessionStream } from "./stream";

async function main() {
  const url = import.meta.url;
  const index = url.lastIndexOf("#");
  if (index === -1) {
    throw new Error("No # found in script url");
  }
  const id = url.slice(index + 1);
  console.log(import.meta.url);

  const status = document.createElement("pre");
  document.body.appendChild(status);
  status.style.background = "#ccc";
  status.textContent = "Connecting..";
  const state = document.createElement("pre");
  document.body.appendChild(state);
  state.style.background = "#ccc";
  state.textContent = "";

  for await (const [event, payload] of sessionStream(id)) {
    switch (event) {
      case "system.connected":
        status.style.background = "#cfc";
        status.textContent = "Connected!";
        break;
      case "system.disconnected":
        status.style.background = "#fcc";
        status.textContent = "Disconnected...";
        break;
      case "session.transfer":
        console.info("Transferring!");
        status.style.background = "#ffc";
        status.textContent = "Transferring...";
        break;
      case "ping":
        console.table({
          client: { ping: payload.client },
          server: { ping: payload.server },
          mean: { ping: (payload.client + payload.server) / 2.0 },
        });
        break;
      case "session.state":
        state.textContent = JSON.stringify(payload, null, 2);
        break;
      default:
        console.log(event, payload);
        break;
    }
  }
}

export default main();
