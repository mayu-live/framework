class PingTimer {
  static PING_FREQUENCY_MS = 2_000;
  static PING_TIMEOUT_MS = this.PING_FREQUENCY_MS * 3;
  static RETRY_TIME_MS = 1_000;

  #pingPromises = new Map<number, (timestamp: number) => void>();

  ping(callback: (timestamp: number) => void): Promise<number> {
    return new Promise(async (resolve, reject) => {
      const now = new Date().getTime();

      const timeout = setTimeout(async () => {
        console.log("Timed out");
        this.#pingPromises.delete(now);
        reject("timeout");
      }, PingTimer.PING_TIMEOUT_MS);

      this.#pingPromises.set(now, (timestamp) => {
        clearTimeout(timeout);
        const pingTime = new Date().getTime() - timestamp;
        resolve(pingTime);
      });

      callback(now);
    });
  }

  sleep(milliseconds: number) {
    return new Promise<void>((resolve) => {
      setTimeout(() => resolve(), milliseconds);
    });
  }

  pong(timestamp: number) {
    const resolve = this.#pingPromises.get(timestamp);

    if (!resolve) {
      console.error("Got unexpected pong with timestamp", timestamp);
      return;
    }

    this.#pingPromises.delete(timestamp);
    resolve(timestamp);
  }
}

export default PingTimer;
