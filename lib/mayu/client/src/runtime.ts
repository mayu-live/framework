// Copyright Andreas Alin <andreas.alin@gmail.com>
// License: AGPL-3.0

import { updatePing } from "./ping";
import { setTransferState } from "./transfer";
import renderError, { clearRenderError } from "./renderError";
import withViewTransition from "./view-transition";
import type { Batch, CommandErrorPolicy } from "./protocol";

type IdNode = {
  id: string;
  name: string;
  children: IdNode[];
};

export const COMMAND_ERROR_POLICY: CommandErrorPolicy = "continue";

type RuntimeOptions = {
  commandErrorPolicy?: CommandErrorPolicy;
};

export default class Runtime {
  #nodeSet: NodeSet;
  #commandErrorPolicy: CommandErrorPolicy;

  constructor(
    onEvent: (event: Event, listenerId: string) => void,
    { commandErrorPolicy = COMMAND_ERROR_POLICY }: RuntimeOptions = {},
  ) {
    this.#nodeSet = new NodeSet(onEvent, commandErrorPolicy);
    this.#commandErrorPolicy = commandErrorPolicy;
  }

  async applyBatch(batch: Batch) {
    await applyCommands(this.#nodeSet, batch, this.#commandErrorPolicy);
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
  #listeners = new Map<
    Element,
    Map<string, { id: string; callback: EventListener }>
  >();
  #onEvent: (event: Event, listenerId: string) => void;
  readonly commandErrorPolicy: CommandErrorPolicy;

  constructor(
    onEvent: (event: Event, listenerId: string) => void,
    commandErrorPolicy: CommandErrorPolicy = COMMAND_ERROR_POLICY,
  ) {
    this.#onEvent = onEvent;
    this.commandErrorPolicy = commandErrorPolicy;
  }

  clear() {
    for (const [element, listeners] of this.#listeners) {
      for (const [name, listener] of listeners) {
        element.removeEventListener(name, listener.callback);
      }
    }
    this.#listeners.clear();
    this.#nodes = {};
  }

  setListener(id: string, name: string, listenerId: string) {
    const element = this.getElement(id);
    let listeners = this.#listeners.get(element);
    if (!listeners) {
      listeners = new Map();
      this.#listeners.set(element, listeners);
    }

    const current = listeners.get(name);
    if (current?.id === listenerId) return;
    if (current) element.removeEventListener(name, current.callback);

    const callback: EventListener = (event) => this.#onEvent(event, listenerId);
    element.addEventListener(name, callback);
    listeners.set(name, { id: listenerId, callback });
  }

  removeListener(id: string, name: string, listenerId: string) {
    const element = this.getElement(id);
    const listeners = this.#listeners.get(element);
    const current = listeners?.get(name);
    if (!current || current.id !== listenerId) return;

    element.removeEventListener(name, current.callback);
    listeners!.delete(name);
    if (listeners!.size === 0) this.#listeners.delete(element);
  }

  removeListeners(node: Node) {
    if (!(node instanceof Element)) return;
    const listeners = this.#listeners.get(node);
    if (!listeners) return;
    for (const [name, listener] of listeners) {
      node.removeEventListener(name, listener.callback);
    }
    this.#listeners.delete(node);
  }

  deleteNode(id: string) {
    const node = this.#nodes[id];
    if (!node) return;
    // console.debug(`%cDeleting ${id}`, "color: #c00; font-weight: bold; font-size: 1.5em;", node)
    delete this.#nodes[id];
    const nodeInfo = this.getNodeInfo(node);
    this.removeListeners(node);
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

    if (node instanceof SVGElement) {
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
]);

function createDomElement(type: string): Element {
  const tag = type.toLowerCase();
  if (SVG_TAGS.has(tag)) {
    return document.createElementNS(SVG_NAMESPACE, type);
  }

  return document.createElement(type);
}

function createTreeRootNode(html: string, tree: IdNode): Node {
  const rootTag = tree.name.toLowerCase();
  const isSvgRoot = SVG_TAGS.has(rootTag);
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
    const root = content.firstChild;
    if (!root)
      throw new Error(`CreateTree: missing root node for ${tree.name}`);
    return root;
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
  const root = svgChildren[0] || svgWrapper.firstChild;
  if (!root)
    throw new Error(`CreateTree: missing SVG root node for ${tree.name}`);
  return root;
}

function debugTree(node: IdNode, level = 0): string {
  return [
    ["  ".repeat(level), node.name, " (", node.id, ")"].join(""),
    ...(node.children || []).map((child) => debugTree(child, level + 1)),
  ]
    .flat()
    .join("\n");
}

const configuredLinks = new WeakSet<HTMLAnchorElement>();

function configureLink(a: HTMLAnchorElement) {
  if (configuredLinks.has(a)) return;
  configuredLinks.add(a);
  a.addEventListener("click", (e) => {
    if (a.host !== location.host) {
      return;
    }

    if (a.target === "_blank") {
      return;
    }

    if (e.metaKey) {
      return;
    }

    e.preventDefault();
    window.Mayu.navigate(a.pathname + a.search);
  });
}

function setupTree(nodeSet: NodeSet, domNode: Node, idNode: IdNode) {
  if (!domNode) return;

  if (domNode.nodeName.toUpperCase() !== idNode.name.toUpperCase()) {
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
  console.log("UPDATE HEAD");
  const oldChildIds = nodeInfo.childIds;

  const existingNodes = new Map();

  oldChildIds.forEach((id, i) => {
    existingNodes.set(id, element.childNodes[i]);
  });

  newChildIds.forEach((id) => {
    existingNodes.set(id, nodeSet.getNode(id));
  });

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

async function applyCommands(
  nodeSet: NodeSet,
  batch: Batch,
  errorPolicy: CommandErrorPolicy,
) {
  for (const [index, command] of batch.entries()) {
    const [name, ...args] = command;

    const handler = CommandHandlers[
      name as keyof typeof CommandHandlers
    ] as any;

    try {
      if (!handler) throw new Error(`Unknown command: ${name}`);

      const result = handler.apply(nodeSet, args as any);
      if (result instanceof Promise) await result;
    } catch (error) {
      console.error(`Command ${index} (${name}) failed`, error);
      if (errorPolicy === "throw") throw error;
    }
  }
}

const CommandHandlers = {
  async ViewTransition(this: NodeSet, batch: Batch) {
    return withViewTransition(() =>
      applyCommands(this, batch, this.commandErrorPolicy),
    );
  },

  Initialize(this: NodeSet, tree: IdNode) {
    console.debug(`%c${debugTree(tree)}`, "color: #6cf;");

    this.clear();
    setupTree(this, document, tree);
  },
  CreateTree(this: NodeSet, html: string, tree: IdNode) {
    setupTree(this, createTreeRootNode(html, tree), tree);
  },
  CreateElement(this: NodeSet, id: string, type: string) {
    this.setNode(id, createDomElement(type));
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
    (this.getElement(id) as HTMLElement).className = value;
  },
  AddClass(this: NodeSet, id: string, classes: string[]) {
    (this.getElement(id) as HTMLElement).classList.add(...classes);
  },
  RemoveClass(this: NodeSet, id: string, classes: string[]) {
    (this.getElement(id) as HTMLElement).classList.remove(...classes);
  },
  SetAttribute(this: NodeSet, id: string, name: string, value: string) {
    const element = this.getElement(id);

    if (name === "open") {
      if (element instanceof HTMLDialogElement) {
        element.showModal();
      }
    }

    if (element instanceof HTMLInputElement) {
      switch (name) {
        case "value": {
          element.value = value;
          break;
        }
        case "checked": {
          element.checked = true;
          break;
        }
        case "indeterminate": {
          element.indeterminate = true;
          return;
        }
      }
    }

    if (name === "initial_value") {
      name = "value";
    } else {
      name = name.replaceAll(/_/g, "");
    }

    element.setAttribute(name, value);
  },
  RemoveAttribute(this: NodeSet, id: string, name: string) {
    const element = this.getElement(id);

    if (name === "open") {
      if (element instanceof HTMLDialogElement) {
        element.open = false;
        element.close();
      }
    }

    if (element instanceof HTMLInputElement) {
      switch (name) {
        case "value": {
          element.value = "";
          break;
        }
        case "checked": {
          element.checked = false;
          break;
        }
        case "indeterminate": {
          element.indeterminate = false;
          return;
        }
      }
    }

    element.removeAttribute(name);
  },
  SetListener(this: NodeSet, id: string, name: string, listenerId: string) {
    this.setListener(id, name, listenerId);
  },
  RemoveListener(this: NodeSet, id: string, name: string, listenerId: string) {
    this.removeListener(id, name, listenerId);
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
        return;
      }

      nodeInfo.childIds.forEach((id) => {
        if (!childIds.includes(id)) {
          this.deleteNode(id);
        }
      });
    }

    element.replaceChildren(...this.getNodes(childIds));

    requestIdleCallback(() => {
      handleAutofocus(element);
    });
  },
  Transfer(this: NodeSet, state: Blob) {
    console.log("Transfer", state);
    setTransferState(state);
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
    source: string | null,
    treePath: { name: string; path?: string }[],
    line: number | null,
    column: number | null,
    hints: string[],
  ) {
    renderError(
      file,
      type,
      message,
      backtrace,
      source,
      treePath,
      line,
      column,
      hints,
    );
  },
  ReloadSucceeded(this: NodeSet) {
    clearRenderError();
  },
  RegisterCustomElement(name: string, path: string) {
    if (customElements.get(name)) return;

    (async () => {
      const mod = await import(path);
      customElements.define(name, mod.default);
    })();
  },
} as const;

function handleAutofocus(node: Node) {
  if (node instanceof HTMLInputElement) {
    if (node.autofocus) {
      node.focus();
      return;
    }
  }

  for (const child of node.childNodes) {
    handleAutofocus(child);
  }
}
