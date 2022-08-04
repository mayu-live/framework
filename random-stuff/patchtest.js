import { Window, DOMParser } from "happy-dom";
import prettier from "prettier";

import NodeTree from "./lib/mayu/client/dist/NodeTree.js";
import patchSets from "./patches.json" assert { type: "json" };

globalThis.DOMParser = DOMParser;

function format(html) {
  console.log(prettier.format(html, { parser: "html" }).slice(0, -1));
}

const window = new Window();
const document = window.document;

const initialPatchSet = patchSets.shift();
console.log(initialPatchSet);
const initial = initialPatchSet.patches[0];

document.body.innerHTML = initial.html;
console.log(document.body.innerHTML);
const nodeTree = new NodeTree(initial.ids, document.body.firstElementChild);

expectEqual(document.body.innerHTML, initialPatchSet.output);

function expectEqual(actual, expected) {
  if (actual === expected) {
    format(`\x1b[32m${actual}\x1b[0m`);
    return;
  }

  console.log("#################");
  format(`\x1b[31m${actual}\x1b[0m`);
  console.log("-------vs--------");
  format(`\x1b[31m${expected}\x1b[0m`);
  console.log("#################");
}

function applyPatch(patch) {
  const { type, id, ...rest } = patch;

  console.log(`  \x1b[35mAPPLYING ${type} to ${id}\x1b[0m`, rest);

  nodeTree.applyPatch(patch);
  format(`\x1b[34m${document.body.innerHTML}\x1b[0m`);
}

patchSets.forEach(({ patches, output }, i) => {
  console.log(`\x1b[35mPATCH SET ${i}\x1b[0m`);

  patches.map(applyPatch);
  // patches.filter((patch) => patch.type == "insert").map(applyPatch)
  // patches.filter((patch) => patch.type !== "insert" && patch.type !== "remove").map(applyPatch)
  // patches.filter((patch) => patch.type == "remove").map(applyPatch)

  expectEqual(document.body.innerHTML, output);
});
