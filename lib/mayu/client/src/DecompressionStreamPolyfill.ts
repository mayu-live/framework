import { AsyncInflate } from "fflate";

class DecompressionStreamPolyfill extends TransformStream<
  Uint8Array,
  Uint8Array
> {
  constructor(_format: "deflate-raw") {
    let decompressor: AsyncInflate;

    super({
      start(controller) {
        decompressor = new AsyncInflate();

        decompressor.ondata = (err, chunk: Uint8Array, final: boolean) => {
          if (err) {
            controller.error(err);
            return;
          }

          if (final) {
            controller.terminate();
          } else {
            controller.enqueue(chunk);
          }
        };
      },
      transform(chunk, controller) {
        try {
          decompressor.push(chunk, false);
        } catch (e) {
          controller.error(
            new Error(`DecompressionStreamPolyfill inflation failure: ${e}`)
          );
        }
      },
      flush() {
        decompressor.push(new Uint8Array(), true);
      },
    });
  }
}

export default DecompressionStreamPolyfill as typeof DecompressionStream;
