import { defineConfig } from "vitest/config";

// Custom elements import their template as a string, the way the rollup build
// serves it. Without this vite tries to parse the .html file as JavaScript.
function htmlAsString() {
  return {
    name: "htmlAsString",
    enforce: "pre" as const,
    transform(code: string, id: string) {
      if (!id.endsWith(".html")) return;

      return {
        code: `export default ${JSON.stringify(code)};`,
        map: null,
      };
    },
  };
}

export default defineConfig({
  plugins: [htmlAsString()],
  test: {
    environment: "jsdom",
    include: ["src/**/*.test.ts"],
    clearMocks: true,
  },
});
