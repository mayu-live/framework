// Copyright Andrés Alin <andreas.alin@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// The tree the server's inspector answers a "tree" query with. See
// gems/mayu-devtools/lib/mayu/devtools/inspector.rb.
export type TreeNode = {
  id: string;
  type: "document" | "component" | "element";
  name: string;
  path?: string | null;
  internal?: boolean;
  // Element classes: the name in the source, when the owning component's
  // styles define it, and the class in the page. Scope classes are the ones
  // Klenod adds for a component's tag selectors.
  classes?: { source: string | null; rendered: string; scope?: boolean }[];
  children: TreeNode[];
};

// An element as the Elements panel shows it, with its classes named as in
// the source: <a.title>.
export function elementLabel(node: TreeNode) {
  const classes = (node.classes ?? [])
    .filter((name) => !name.scope)
    .map((name) => `.${name.source ?? name.rendered}`)
    .join("");
  return `<${node.name}${classes}>`;
}

export function isTree(value: unknown): value is TreeNode {
  return (
    typeof value === "object" &&
    value !== null &&
    typeof (value as TreeNode).id === "string" &&
    Array.isArray((value as TreeNode).children)
  );
}

// The nodes from the root down to the node with the id, or null when the
// tree doesn't have it.
export function findPath(root: TreeNode, id: string): TreeNode[] | null {
  if (root.id === id) return [root];

  for (const child of root.children) {
    const path = findPath(child, id);
    if (path) return [root, ...path];
  }

  return null;
}

// The components a node is rendered by, innermost first. A component
// counts as rendering itself.
export function ownerComponents(root: TreeNode, id: string): TreeNode[] {
  const path = findPath(root, id) ?? [];
  return path.filter((node) => node.type === "component").reverse();
}

// The tree with only the document and its components. The children of a
// removed node take its place.
export function componentTree(
  root: TreeNode,
  { internal = false }: { internal?: boolean } = {},
): TreeNode {
  const keep = (node: TreeNode) =>
    node.type === "component" && (internal || !node.internal);

  const children = (node: TreeNode): TreeNode[] =>
    node.children.flatMap((child) =>
      keep(child) ? [{ ...child, children: children(child) }] : children(child),
    );

  return { ...root, children: children(root) };
}

// The outermost elements a node renders: the node itself for an element.
// Revealing a component in the Elements panel goes to the first of them, and
// highlighting it covers them all.
export function topElements(node: TreeNode): TreeNode[] {
  if (node.type === "element") return [node];
  return node.children.flatMap(topElements);
}

// The rows to flash for DOM changes to the elements with the ids: the
// elements themselves, or in the component view their closest shown
// component.
export function updatedRows(
  tree: TreeNode,
  ids: string[],
  {
    componentsOnly,
    internal = false,
  }: { componentsOnly: boolean; internal?: boolean },
): string[] {
  const rows = new Set<string>();

  for (const id of ids) {
    if (!componentsOnly) {
      if (findPath(tree, id)) rows.add(id);
      continue;
    }

    const owner = ownerComponents(tree, id).find(
      (component) => internal || !component.internal,
    );
    if (owner) rows.add(owner.id);
  }

  return [...rows];
}
