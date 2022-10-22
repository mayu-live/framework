import { Inflate } from "fflate";

class DecompressionStreamPolyfill extends TransformStream<
  Uint8Array,
  Uint8Array
> {
  constructor(_format: "deflate") {
    let decompressor: Inflate;

    super({
      async start(controller) {
        decompressor = new Inflate((chunk: Uint8Array, final: boolean) => {
          console.log(chunk);
          if (final) {
            controller.terminate();
          } else {
            controller.enqueue(chunk);
          }
        });
      },
      async transform(chunk) {
        console.log(chunk);
        decompressor.push(chunk, false);
      },
      flush() {
        decompressor.push(new Uint8Array(), true);
      },
    });
  }
}

export default DecompressionStreamPolyfill as typeof DecompressionStream;
