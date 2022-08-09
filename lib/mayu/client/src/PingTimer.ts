type Pong = {
  time: number;
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
      const now = new Date().getTime();

      const timeout = setTimeout(async () => {
        console.log("Timed out");
        this.#pingPromises.delete(now);
        reject("timeout");
      }, PingTimer.PING_TIMEOUT_MS);

      this.#pingPromises.set(now, ({ time, region }) => {
        clearTimeout(timeout);
        const ping = new Date().getTime() - time;
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

  pong({ time, region }: Pong) {
    const resolve = this.#pingPromises.get(time);

    if (!resolve) {
      console.error("Got unexpected pong with time", time);
      return;
    }

    this.#pingPromises.delete(time);
    resolve({ time, region });
  }
}

export default PingTimer;
