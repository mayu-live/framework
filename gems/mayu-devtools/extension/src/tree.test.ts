import { describe, expect, it } from "vitest";

import {
  componentTree,
  elementLabel,
  findPath,
  ownerComponents,
  topElements,
  type TreeNode,
} from "./tree";

function node(
  id: string,
  type: TreeNode["type"],
  name: string,
  children: TreeNode[] = [],
  internal = false,
): TreeNode {
  return { id, type, name, internal, children };
}

// document > Html (internal) > body > App > ul > Item > li
const tree = node("v1", "document", "#document", [
  node(
    "v2",
    "component",
    "Html",
    [
      node("v3", "element", "body", [
        node("v4", "component", "App", [
          node("v5", "element", "ul", [
            node("v6", "component", "Item", [node("v7", "element", "li")]),
          ]),
        ]),
      ]),
    ],
    true,
  ),
]);

describe("findPath", () => {
  it("returns the nodes from the root to the node", () => {
    expect(findPath(tree, "v5")?.map((node) => node.id)).toEqual([
      "v1",
      "v2",
      "v3",
      "v4",
      "v5",
    ]);
  });

  it("returns null for unknown ids", () => {
    expect(findPath(tree, "nope")).toBeNull();
  });
});

describe("ownerComponents", () => {
  it("returns the components rendering a node, innermost first", () => {
    expect(ownerComponents(tree, "v7").map((node) => node.name)).toEqual([
      "Item",
      "App",
      "Html",
    ]);
  });

  it("counts a component as its own owner", () => {
    expect(ownerComponents(tree, "v4")[0].name).toBe("App");
  });
});

describe("componentTree", () => {
  it("keeps components and hoists the rest of their children", () => {
    const components = componentTree(tree);

    expect(components.children.map((node) => node.name)).toEqual(["App"]);
    expect(components.children[0].children.map((node) => node.name)).toEqual([
      "Item",
    ]);
    expect(components.children[0].children[0].children).toEqual([]);
  });

  it("keeps internal components when asked to", () => {
    const components = componentTree(tree, { internal: true });

    expect(components.children.map((node) => node.name)).toEqual(["Html"]);
  });
});

describe("topElements", () => {
  it("finds the outermost elements a component renders", () => {
    const fragment = node("c", "component", "Fragment", [
      node("a", "element", "p", [node("x", "element", "span")]),
      node("inner", "component", "Inner", [node("b", "element", "hr")]),
    ]);

    expect(topElements(fragment).map((child) => child.id)).toEqual(["a", "b"]);
  });

  it("returns an element itself", () => {
    const ul = findPath(tree, "v5")!.at(-1)!;

    expect(topElements(ul).map((child) => child.id)).toEqual(["v5"]);
  });
});

describe("elementLabel", () => {
  it("names classes as in the source, and the rest as in the page", () => {
    const link: TreeNode = {
      ...node("a1", "element", "a"),
      classes: [
        { source: null, rendered: "Header_a_2", scope: true },
        { source: "title", rendered: "Header_title_1" },
        { source: null, rendered: "literal" },
      ],
    };

    expect(elementLabel(link)).toBe("<a.title.literal>");
  });

  it("shows elements without classes by their tag", () => {
    expect(elementLabel(node("p1", "element", "p"))).toBe("<p>");
  });
});
