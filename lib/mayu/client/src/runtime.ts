// Copyright Andreas Alin <andreas.alin@gmail.com>
// License: AGPL-3.0

// const startViewTransition =
//   document.startViewTransition?.bind(document) || ((cb: () => void) => cb())

import { updatePing } from "./ping";
import { setTransferState } from "./transfer";
import renderError from "./renderError";

type IdNode = {
  id: string;
  name: string;
  children: IdNode[];
};

type PatchType = keyof typeof Patches;

type Patch = [id: string, name: PatchType, ...args: string[]];

type PatchSet = Patch[];

export default class Runtime {
  #nodeSet = new NodeSet();

  apply(patches: PatchSet) {
    for (const patch of patches) {
      const [name, ...args] = patch;
      console.debug(name, args);
      const patchFn = Patches[name as PatchType] as any;
      if (!patchFn) {
        throw new Error(`Not implemented: ${name}`);
      }
      try {
        patchFn.apply(this.#nodeSet, args as any);
      } catch (e) {
        console.error(e)
      }
    }
  }
}

type NodeInfo = {
  id: string;
  childIds: string[];
};

function initNodeInfo(id: string, childIds: string[] = []): NodeInfo {
  return {
    id,
    childIds,
  };
}

class NodeSet {
  #nodes: Record<string, Node> = {};
  #nodeInfo = new WeakMap<Node, NodeInfo>();

  clear() {
    this.#nodes = {};
  }

  deleteNode(id: string) {
    const node = this.#nodes[id];
    if (!node) return;
    // console.debug(`%cDeleting ${id}`, "color: #c00; font-weight: bold; font-size: 1.5em;", node)
    delete this.#nodes[id];
    const nodeInfo = this.getNodeInfo(node);
    this.#nodeInfo.delete(node);
    if (nodeInfo) {
      nodeInfo.childIds.forEach((childId) => this.deleteNode(childId));
    }
  }

  setNode(id: string, node: Node) {
    this.#nodes[id] = node;
    const nodeInfo = initNodeInfo(id);
    this.#nodeInfo.set(node, nodeInfo);
    return nodeInfo;
  }

  getNode(id: string) {
    const node = this.#nodes[id];

    if (!node) {
      throw new Error(`Node not found: ${id}`);
    }

    return node;
  }

  getNodeInfo(node: Node) {
    return this.#nodeInfo.get(node);
  }

  getNodes(ids: string[]) {
    return ids.map((id) => this.getNode(id));
  }

  getElement(id: string) {
    const node = this.getNode(id);

    if (node instanceof HTMLElement) {
      return node;
    }

    throw new Error(`Node ${id} is not an Element`);
  }

  getCharacterData(id: string) {
    const node = this.getNode(id);

    if (node instanceof CharacterData) {
      return node;
    }

    throw new Error(`Node ${id} is not a CharacterData`);
  }
}

function debugTree(node: IdNode, level = 0): string {
  return [
    ["  ".repeat(level), node.name, " (", node.id, ")"].join(""),
    ...(node.children || []).map((child) => debugTree(child, level + 1)),
  ]
    .flat()
    .join("\n");
}

function configureLink(a: HTMLAnchorElement) {
  a.addEventListener("click", (e) => {
    if (a.host !== location.host) {
      return;
    }

    e.preventDefault();
    window.Mayu.navigate(a.pathname + a.search);
  });
}

function setupTree(nodeSet: NodeSet, domNode: Node, idNode: IdNode) {
  if (!domNode) return;

  // console.log("Visiting", domNode, domNode.nodeName, idNode.name, JSON.stringify(domNode.textContent));

  if (domNode.nodeName !== idNode.name) {
    console.error(
      `Node ${idNode.id} should be ${idNode.name}, but found ${domNode.nodeName}`,
    );
  }

  const nodeInfo = nodeSet.setNode(idNode.id, domNode);

  if (domNode.nodeName === "A") {
    configureLink(domNode as HTMLAnchorElement);
  }

  if (!idNode.children) return;

  const childNodes = Array.from(domNode.childNodes).filter(
    (child) => child.nodeType !== Node.DOCUMENT_TYPE_NODE,
  );

  nodeInfo.childIds = idNode.children.map((child) => child.id);

  idNode.children.forEach((child, i) => {
    setupTree(nodeSet, childNodes[i], child);
  });
}

declare global {
  interface ObjectConstructor {
    groupBy<Item, Key extends PropertyKey>(
      items: Iterable<Item>,
      keySelector: (item: Item, index: number) => Key,
    ): Record<Key, Item[]>;
  }

  interface MapConstructor {
    groupBy<Item, Key>(
      items: Iterable<Item>,
      keySelector: (item: Item, index: number) => Key,
    ): Map<Key, Item[]>;
  }
}

function updateHead(
  nodeSet: NodeSet,
  element: Element,
  nodeInfo: NodeInfo,
  newChildIds: string[],
) {
  console.log("UPDATE HEAD")
  const oldChildIds = nodeInfo.childIds;

  const existingNodes = new Map()

  oldChildIds.forEach((id, i) => {
    existingNodes.set(id, element.childNodes[i])
  })

  newChildIds.forEach((id) => {
    existingNodes.set(id, nodeSet.getNode(id))
  })

  // Remove nodes that are no longer needed
  oldChildIds.forEach((id) => {
    if (newChildIds.includes(id)) return;
    if (!existingNodes.has(id)) return;
    const nodeToRemove = existingNodes.get(id);
    if (!nodeToRemove) return;
    element.removeChild(nodeToRemove);
    existingNodes.delete(id); // Ensure to remove from the map as well
    nodeSet.deleteNode(id);
  });

  // Insert or move nodes to match the newChildIds order
  let lastInsertedNode: Element | null = null;
  newChildIds.forEach((id, index) => {
    let node = existingNodes.get(id) as Element;

    if (node) {
      // If the node exists but is not in the correct order, move it
      if (lastInsertedNode && lastInsertedNode.nextSibling !== node) {
        element.insertBefore(node, lastInsertedNode.nextSibling);
      }
    } else {
      // If the node doesn't exist, insert it
      node = nodeSet.getNode(id) as Element; // Assuming nodeSet.getNode(id) returns an Element or Node

      if (node) {
        // If lastInsertedNode is null, insert as the first child or before the first existing node in newChildIds found in the head
        if (!lastInsertedNode) {
          const nextExistingNode =
            newChildIds
              .slice(index + 1)
              .find((nextId) => existingNodes.get(nextId)) ?? null;
          const nextNode =
            (nextExistingNode
              ? existingNodes.get(nextExistingNode)
              : element.firstChild) || null;
          element.insertBefore(node, nextNode);
        } else {
          element.insertBefore(node, lastInsertedNode.nextSibling);
        }
        existingNodes.set(id, node); // Add to the map for future look-ups
      }
    }
    lastInsertedNode = node;
  });

  nodeInfo.childIds = newChildIds;
}

const Patches = {
  Initialize(this: NodeSet, tree: IdNode) {
    console.debug(`%c${debugTree(tree)}`, "color: #6cf;");

    this.clear();
    setupTree(this, document, tree);
  },
  CreateTree(this: NodeSet, html: string, tree: IdNode) {
    const template = document
      .createRange()
      .createContextualFragment(
        `<template>${html}</template>`,
      ).firstElementChild!;
    const content = (template as HTMLTemplateElement).content;

    setupTree(this, content.firstChild!, tree);
  },
  CreateElement(this: NodeSet, id: string, type: string) {
    this.setNode(id, document.createElement(type));
  },
  CreateTextNode(this: NodeSet, id: string, content: string) {
    this.setNode(id, document.createTextNode(content));
  },
  CreateComment(this: NodeSet, id: string, content: string) {
    this.setNode(id, document.createComment(content));
  },
  RemoveNode(this: NodeSet, id: string) {
    this.deleteNode(id);
  },
  HistoryPushState(this: NodeSet, path: string) {
    const currentPath = location.pathname + location.search;

    if (currentPath === path) return;

    console.warn("pushState going from", currentPath, "to", path);

    history.pushState({ path: currentPath }, "", path);
  },
  SetClassName(this: NodeSet, id: string, value: string) {
    this.getElement(id).className = value;
  },
  SetAttribute(this: NodeSet, id: string, name: string, value: string) {
    this.getElement(id).setAttribute(name, value);
  },
  RemoveAttribute(this: NodeSet, id: string, name: string) {
    this.getElement(id).removeAttribute(name);
  },
  SetCSSProperty(this: NodeSet, id: string, name: string, value: string) {
    this.getElement(id).style.setProperty(name, value);
  },
  RemoveCSSProperty(this: NodeSet, id: string, name: string) {
    this.getElement(id).style.removeProperty(name);
  },
  SetTextContent(this: NodeSet, id: string, content: string) {
    this.getCharacterData(id).data = content;
  },
  ReplaceChildren(this: NodeSet, id: string, childIds: string[]) {
    const element = this.getElement(id);
    const nodeInfo = this.getNodeInfo(element);

    if (nodeInfo) {
      if (element.nodeName === "HEAD") {
        updateHead(this, element, nodeInfo, childIds);
        return
      }

      nodeInfo.childIds.forEach((id) => {
        if (!childIds.includes(id)) {
          this.deleteNode(id)
        }
      })
    }

    element.replaceChildren(...this.getNodes(childIds));
  },
  Transfer(this: NodeSet, state: Blob) {
    console.log("Transfer", state);
    setTransferState(state);
  },
  AddStyleSheet(this: NodeSet, path: string) {
    console.error(path);
    console.error(path);
    console.error(path);
    console.error(path);
    console.error(path);
    console.error(path);
    console.error(path);
  },
  Pong(this: NodeSet, timestamp: number) {
    updatePing(performance.now() - timestamp);
  },
  RenderError(
    this: NodeSet,
    file: string,
    type: string,
    message: string,
    backtrace: string[],
    source: string,
    treePath: { name: string; path?: string }[],
  ) {
    renderError(file, type, message, backtrace, source, treePath);
  },
} as const;
