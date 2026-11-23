// Prints the size of every built chunk, and fails when the code a page
// loads eagerly has outgrown its budget. Run after a build: `npm run size`.
//
// The runtime should stay as small as possible. Lower the budget whenever a
// change makes the eager chunks smaller, so the saving can't quietly be lost.

import { readdirSync, readFileSync } from "node:fs";
import { join, relative } from "node:path";
import { gzipSync } from "node:zlib";

// Gzipped bytes of the chunks every page loads: init and main.
const EAGER_BUDGET = 11_100;
const EAGER_CHUNKS = /^(init|main)-/;

const dist = new URL("../dist/", import.meta.url).pathname;

function chunks(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return chunks(path);
    return entry.name.endsWith(".js") ? [path] : [];
  });
}

let eager = 0;

for (const path of chunks(dist).sort()) {
  const source = readFileSync(path);
  const gzip = gzipSync(source).byteLength;
  const name = relative(dist, path);
  const isEager = EAGER_CHUNKS.test(name);
  if (isEager) eager += gzip;

  console.log(
    `${String(source.byteLength).padStart(7)} B ${String(gzip).padStart(6)} B gzip  ${name}${isEager ? "  (eager)" : ""}`,
  );
}

console.log(`eager: ${eager} B gzip, budget ${EAGER_BUDGET} B`);

if (eager > EAGER_BUDGET) {
  console.error(`The eager chunks are ${eager - EAGER_BUDGET} B over budget.`);
  process.exit(1);
}
