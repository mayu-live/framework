import { defineConfig } from "rolldown";
import { execFileSync } from "child_process";
import { rmSync } from "fs";

// Content scripts, background scripts and the pages of a devtools extension
// all load classic scripts, so every entry is its own self-contained IIFE.
const entries = {
  hook: "src/hook.ts",
  bridge: "src/bridge.ts",
  background: "src/background.ts",
  devtools: "src/devtools.ts",
  panel: "src/panel/main.tsx",
};

// Removes the previous build once, so that rebuilding one entry in watch mode
// doesn't remove the others.
function clean() {
  let cleaned = false;

  return {
    name: "clean",
    buildStart() {
      if (cleaned) return;
      cleaned = true;
      rmSync("dist", { recursive: true, force: true });
    },
  };
}

// The build script packages once after all entries are built. In watch
// mode, package again after every rebuild.
function packageOnRebuild() {
  return {
    name: "packageOnRebuild",
    writeBundle() {
      if (!this.meta.watchMode) return;
      execFileSync(process.execPath, ["scripts/package.js"], {
        stdio: "inherit",
      });
    },
  };
}

export default defineConfig(
  Object.entries(entries).map(([name, input], index) => ({
    input,
    output: {
      file: `dist/build/${name}.js`,
      format: "iife",
      sourcemap: true,
    },
    plugins: [index === 0 && clean(), packageOnRebuild()],
  })),
);
