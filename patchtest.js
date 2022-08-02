import { Window, DOMParser } from 'happy-dom';
import prettier from 'prettier';

import NodeTree from './lib/mayu/client/dist/NodeTree.js'
import patchSets from './patches.json' assert { type: "json" };

globalThis.DOMParser = DOMParser

function format(html) {
  console.log(
    prettier.format(html, { parser: 'html' })
  )
}

const window = new Window();
const document = window.document;

const initialPatchSet = patchSets.shift();
console.log(initialPatchSet)
const initial = initialPatchSet[0];

document.body.innerHTML = initial.html
const nodeTree = new NodeTree(initial.ids, document.body.firstElementChild)

format(document.body.innerHTML)

patchSets.forEach((patches, i) => {
  console.log(`\x1b[35mPATCH SET ${i}\x1b[0m`)
  patches.forEach((patch) => {
    console.log('  \x1b[35mAPPLYING\x1b[0m', patch)
    nodeTree.applyPatch(patch)
  })
  format(document.body.innerHTML)
})
