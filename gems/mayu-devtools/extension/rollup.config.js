import typescript from "@rollup/plugin-typescript";
import { nodeResolve } from "@rollup/plugin-node-resolve";
import del from "rollup-plugin-delete";

// Content scripts, background scripts and the pages of a devtools extension
// all load classic scripts, so every entry is its own self-contained IIFE.
const entries = {
  hook: "src/hook.ts",
  bridge: "src/bridge.ts",
  background: "src/background.ts",
  devtools: "src/devtools.ts",
  panel: "src/panel/main.tsx",
};

export default Object.entries(entries).map(([name, input], index) => ({
  input,
  output: {
    file: `dist/build/${name}.js`,
    format: "iife",
    sourcemap: true,
  },
  plugins: [
    index === 0 && del({ targets: "dist/*" }),
    typescript({ noEmit: false }),
    nodeResolve(),
  ],
}));
