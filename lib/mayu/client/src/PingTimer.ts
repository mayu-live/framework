type Pong = {
  timestamp: number;
  region: string;
};

type Result = {
  ping: number;
  region: string;
};

class PingTimer {
  static PING_FREQUENCY_MS = 2_000;
  static PING_TIMEOUT_MS = this.PING_FREQUENCY_MS * 3;
  static RETRY_TIME_MS = 1_000;

  #pingPromises = new Map<number, (pong: Pong) => void>();

  ping(callback: (time: number) => void): Promise<Result> {
    return new Promise(async (resolve, reject) => {
      const now = performance.now();

      const timeout = setTimeout(async () => {
        console.error("Timed out");
        this.#pingPromises.delete(now);
        reject("timeout");
      }, PingTimer.PING_TIMEOUT_MS);

      this.#pingPromises.set(now, ({ timestamp, region }) => {
        clearTimeout(timeout);
        const ping = performance.now() - timestamp;
        resolve({ ping, region });
      });

      callback(now);
    });
  }

  sleep(milliseconds: number) {
    return new Promise<void>((resolve) => {
      setTimeout(() => resolve(), milliseconds);
    });
  }

  pong(pong: Pong) {
    const { timestamp, region } = pong;
    const resolve = this.#pingPromises.get(timestamp);

    if (!resolve) {
      console.error("Got unexpected pong with time", timestamp);
      return;
    }

    this.#pingPromises.delete(timestamp);
    resolve({ timestamp, region });
  }
}

export default PingTimer;
