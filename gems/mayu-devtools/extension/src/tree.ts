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
  children: TreeNode[];
};

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
