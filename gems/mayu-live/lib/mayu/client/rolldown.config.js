import { defineConfig } from "rolldown";
import { minify } from "html-minifier-terser";

function entriesJSON() {
  return {
    name: "entriesJSON",
    generateBundle(_outputOptions, bundle) {
      const entries = Object.fromEntries(
        Object.values(bundle)
          .filter((chunk) => chunk.type === "chunk" && chunk.isEntry)
          .map((chunk) => [chunk.name, chunk.fileName]),
      );

      this.emitFile({
        type: "asset",
        fileName: "entries.json",
        source: JSON.stringify(entries) + "\n",
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
        moduleType: "js",
      };
    },
  };
}

export default defineConfig({
  input: ["src/init.ts"],
  output: {
    dir: "dist/",
    cleanDir: true,
    format: "esm",
    entryFileNames: "[name]-[hash].js",
    // Custom elements are loaded on demand from their own directory.
    chunkFileNames: (chunk) =>
      chunk.facadeModuleId?.includes("custom-elements")
        ? "custom-elements/[name]-[hash].js"
        : "[name]-[hash].js",
    assetFileNames: "[name]-[hash][extname]",
    sourcemap: true,
    minify: true,
  },
  plugins: [
    minifyHTML({
      removeComments: true,
      collapseWhitespace: true,
      collapseBooleanAttributes: true,
      removeEmptyAttributes: true,
      minifyJS: true,
      minifyCSS: true,
    }),
    entriesJSON(),
  ],
});
