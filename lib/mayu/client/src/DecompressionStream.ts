import logger from "./logger";

const DecompressionStreamPromise = new Promise<typeof DecompressionStream>(
  async (resolve) => {
    if (typeof DecompressionStream !== "undefined") {
      logger.success("Using standard DecompressionStream");
      return resolve(DecompressionStream);
    }

    logger.warn("Using DecompressionStream polyfill");
    await import("@stardazed/streams-polyfill");

    return resolve(DecompressionStream);
  }
);

export default await DecompressionStreamPromise;
