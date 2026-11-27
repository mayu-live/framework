import type { IdNode } from "../protocol/commands";
import type NodeRegistry from "./node-registry";

const SVG_NAMESPACE = "http://www.w3.org/2000/svg";
const SVG_TAGS = new Set([
  "svg",
  "g",
  "path",
  "rect",
  "text",
  "tspan",
  "textpath",
  "circle",
  "line",
  "polyline",
  "polygon",
  "ellipse",
  "defs",
  "marker",
  "symbol",
  "use",
  "image",
  "pattern",
  "clippath",
  "mask",
  "filter",
  "lineargradient",
  "radialgradient",
  "stop",
  "foreignobject",
  "animate",
  "animatemotion",
  "animatetransform",
  "mpath",
  "set",
]);

// Parses the HTML of a CreateTree command into its root nodes.
export function createTreeRootNodes(html: string, trees: IdNode[]): Node[] {
  const isSvgRoot = trees.every((tree) =>
    SVG_TAGS.has(tree.name.toLowerCase()),
  );
  const wrappedHtml = isSvgRoot
    ? `<svg xmlns="${SVG_NAMESPACE}">${html}</svg>`
    : html;

  const template = document
    .createRange()
    .createContextualFragment(
      `<template>${wrappedHtml}</template>`,
    ).firstElementChild!;
  const content = (template as HTMLTemplateElement).content;

  if (!isSvgRoot) {
    const roots = Array.from(content.childNodes).filter(
      (child) => child.nodeType !== Node.DOCUMENT_TYPE_NODE,
    );
    if (roots.length !== trees.length) {
      throw new Error(
        `CreateTree: expected ${trees.length} root nodes, got ${roots.length}`,
      );
    }
    return roots;
  }

  const svgWrapper = content.firstElementChild;
  if (!svgWrapper) throw new Error("CreateTree: missing svg wrapper");

  const svgChildren = Array.from(svgWrapper.childNodes).filter((child) => {
    if (child.nodeType === Node.DOCUMENT_TYPE_NODE) return false;
    if (
      child.nodeType === Node.TEXT_NODE &&
      (child.textContent == null || child.textContent.trim() === "")
    ) {
      return false;
    }
    return true;
  });
  if (svgChildren.length !== trees.length) {
    throw new Error(
      `CreateTree: expected ${trees.length} SVG root nodes, got ${svgChildren.length}`,
    );
  }
  return svgChildren;
}

// Registers a DOM subtree under the ids the server gave its nodes, by
// walking both trees in parallel. Where the two disagree it registers what
// it can and goes on, and then throws: commands for the nodes it could not
// find would fail later, so the caller asks the server for the page.
export function setupTree(registry: NodeRegistry, domNode: Node, tree: IdNode) {
  const mismatches: string[] = [];
  bind(registry, domNode, tree, mismatches);

  if (mismatches.length > 0) {
    throw new Error(
      `${mismatches.length} nodes differ from the server's tree. ${mismatches[0]}`,
    );
  }
}

function bind(
  registry: NodeRegistry,
  domNode: Node | undefined,
  idNode: IdNode,
  mismatches: string[],
) {
  if (!domNode) {
    mismatches.push(`Node ${idNode.id} (${idNode.name}) is missing`);
    return;
  }

  if (domNode.nodeName.toUpperCase() !== idNode.name.toUpperCase()) {
    mismatches.push(
      `Node ${idNode.id} should be ${idNode.name}, but found ${domNode.nodeName}`,
    );
  }

  const nodeInfo = registry.setNode(idNode.id, domNode);

  // HTML can only set the attribute, and only the property shows. One that
  // a patch set has no attribute, and stays as it is.
  if (
    domNode instanceof HTMLInputElement &&
    domNode.hasAttribute("indeterminate")
  ) {
    domNode.indeterminate = true;
  }

  if (!idNode.children) return;

  if (
    domNode instanceof HTMLTextAreaElement &&
    !domNode.firstChild &&
    idNode.children.length === 1
  ) {
    domNode.appendChild(document.createTextNode(""));
  }

  const childNodes = Array.from(domNode.childNodes).filter(
    (child) => child.nodeType !== Node.DOCUMENT_TYPE_NODE,
  );

  nodeInfo.childIds = idNode.children.map((child) => child.id);

  idNode.children.forEach((child, i) => {
    bind(registry, childNodes[i], child, mismatches);
  });
}
