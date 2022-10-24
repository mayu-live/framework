import typescript from "@rollup/plugin-typescript";
import resolve from "@rollup/plugin-node-resolve";
import commonjs from "@rollup/plugin-commonjs";
import { terser } from "rollup-plugin-terser";
import del from "rollup-plugin-delete";
import { visualizer } from "rollup-plugin-visualizer";
import { minify } from "html-minifier-terser";

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
        source: JSON.stringify(data, null, 2) + "\n",
      });
    },
  };
}

function minifyHTML(minifyOptions = {}) {
  return {
    name: "minifyHTML",
    async transform(code, id) {
      if (!id.endsWith(".html")) return;

      const minified = await minify(code, minifyOptions);

      return {
        code: `export default ${JSON.stringify(minified)};`,
        map: { mappings: "" },
      };
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
    minifyHTML({
      removeComments: true,
      collapseWhitespace: true,
      collapseBooleanAttributes: true,
      removeEmptyAttributes: true,
      minifyJS: true,
      minifyCSS: true,
    }),
    terser(),
    entriesJSON(),
    visualizer({
      gzipSize: true,
      brotliSize: true,
    }),
  ],
};
