import typescript from "@rollup/plugin-typescript";
import resolve from "@rollup/plugin-node-resolve";
import commonjs from "@rollup/plugin-commonjs";
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
    commonjs(),
    resolve(),
    string({
      include: "**/*.html",
    }),
    terser(),
  ],
};
