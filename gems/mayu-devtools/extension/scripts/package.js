// Assembles an unpacked extension for each browser from the rolldown output
// and the static files: dist/chrome and dist/firefox.
import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "fs";
import { join } from "path";

const root = new URL("..", import.meta.url).pathname;
const base = JSON.parse(
  readFileSync(join(root, "static/manifest.json"), "utf8"),
);

const targets = {
  chrome: {
    background: { service_worker: "background.js" },
  },
  firefox: {
    background: { scripts: ["background.js"] },
    browser_specific_settings: {
      gecko: {
        id: "devtools@mayu.live",
        // Content scripts in the page's own world need Firefox 128.
        strict_min_version: "128.0",
      },
    },
  },
};

for (const [target, overrides] of Object.entries(targets)) {
  const out = join(root, "dist", target);
  rmSync(out, { recursive: true, force: true });
  mkdirSync(out, { recursive: true });

  cpSync(join(root, "dist/build"), out, { recursive: true });
  cpSync(join(root, "static"), out, {
    recursive: true,
    filter: (source) => !source.endsWith("manifest.json"),
  });
  writeFileSync(
    join(out, "manifest.json"),
    JSON.stringify({ ...base, ...overrides }, null, 2) + "\n",
  );
}
