import typescript from "@rollup/plugin-typescript";
import resolve from "@rollup/plugin-node-resolve";
import commonjs from "@rollup/plugin-commonjs";
import { terser } from "rollup-plugin-terser";
import { string } from "rollup-plugin-string";
import del from "rollup-plugin-delete";

function entriesJSON() {
  return {
    name: "entriesJSON",
    generateBundle(outputOptions, bundle) {
      const data = {};

      for (const chunk of Object.values(bundle)) {
        if (chunk.isEntry) {
          data[chunk.name] = chunk.fileName;
        }
      }

      this.emitFile({
        type: "asset",
        fileName: "entries.json",
        source: JSON.stringify(data, null, 2),
      });
    },
  };
}

export default {
  input: ["src/main.ts"],
  output: {
    dir: "dist/",
    format: "esm",
    entryFileNames: "[name]-[hash].js",
    chunkFileNames: "[name]-[hash].js",
    assetFileNames: "[name]-[hash][extname]",
    sourcemap: true,
  },
  plugins: [
    del({ targets: "dist/*" }),
    typescript(),
    commonjs(),
    resolve(),
    string({
      include: "**/*.html",
    }),
    terser(),
    entriesJSON(),
  ],
};
