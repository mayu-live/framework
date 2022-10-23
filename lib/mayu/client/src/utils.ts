export function stringifyJSON(payload: any, space?: number) {
  return JSON.stringify(
    payload,
    (_key: string, value: any) => {
      if (typeof value === "bigint") {
        return Number(value);
      } else if (value instanceof Blob) {
        return `Blob{type: ${value.type}, size: ${value.size}}`;
      } else {
        return value;
      }
    },
    space
  );
}

export async function sleep(ms = 1000) {
  return new Promise<void>((resolve) => {
    setTimeout(resolve, ms);
  });
}

export class FatalError extends Error {}

export async function retry<T>(fn: () => Promise<T>): Promise<T> {
  const maxAttempts = 10;
  let attempts = 0;

  while (true) {
    try {
      return await fn();
    } catch (e) {
      if (e instanceof FatalError) {
        throw e;
      }

      if (attempts >= maxAttempts) {
        console.error("Reached the maximum number of attempts!");
        throw e;
      }

      const waitTime = attempts + Math.random();

      console.error(
        `Got error (attempts: ${attempts}, wait: ${waitTime.toFixed(2)})`,
        e
      );

      const logTimes = Math.ceil(waitTime);
      const sleepTime = waitTime / logTimes;

      for (let i = 0; i < logTimes; i++) {
        console.warn(
          `Retrying in ${(waitTime - i * sleepTime).toFixed(2)} seconds`
        );
        await sleep(sleepTime * 1000);
      }

      attempts++;
    }
  }
}

export function* splitChunk(chunk: Uint8Array) {
  let offset = 0;

  while (offset < chunk.byteLength) {
    yield chunk.slice(offset, offset + 1024);
    offset += 1024;
  }
}
