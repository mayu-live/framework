import { AsyncInflate } from "fflate";

// class DecompressionStreamPolyfill extends TransformStream<
//   Uint8Array,
//   Uint8Array
// > {
//   constructor(_format: "deflate") {
//     let decompressor: AsyncInflate;
//
//     super({
//       async start(controller) {
//         decompressor = new AsyncInflate((chunk: Uint8Array, final: boolean) => {
//           if (final) {
//             controller.terminate();
//           } else {
//             controller.enqueue(chunk);
//           }
//         });
//       },
//       async transform(chunk) {
//         decompressor.push(chunk, false);
//       },
//       flush() {
//         decompressor.push(new Uint8Array(), true);
//       },
//     });
//   }
// }

export default function create() {
  let decompressor: AsyncInflate;

  return new TransformStream<Uint8Array, Uint8Array>({
    async start(controller) {
      decompressor = new AsyncInflate((chunk: Uint8Array, final: boolean) => {
        if (final) {
          controller.terminate();
        } else {
          controller.enqueue(chunk);
        }
      });
    },
    async transform(chunk) {
      decompressor.push(chunk, false);
    },
    flush() {
      decompressor.push(new Uint8Array(), true);
    },
  });
}
