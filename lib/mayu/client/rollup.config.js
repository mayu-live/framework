import typescript from "@rollup/plugin-typescript";
import { terser } from "rollup-plugin-terser";
import { string } from "rollup-plugin-string";

export default {
  input: ["src/live.ts", "src/sw.ts"],
  output: {
    dir: "dist/",
    format: "esm",
  },
  plugins: [
    typescript(),
    string({
      include: "**/*.html",
    }),
    terser(),
  ],
};
