type NodeInfo = {
  id: string;
  childIds: string[];
};

type Listener = { id: string; callback: EventListener };

// The DOM nodes the server knows about, by the id it gave them, and the
// event listeners it asked for on them.
export default class NodeRegistry {
  #nodes: Record<string, Node> = {};
  #nodeInfo = new WeakMap<Node, NodeInfo>();
  #listeners = new Map<Element, Map<string, Listener>>();
  #onEvent: (event: Event, listenerId: string) => void;

  constructor(onEvent: (event: Event, listenerId: string) => void) {
    this.#onEvent = onEvent;
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

  #removeListeners(node: Node) {
    if (!(node instanceof Element)) return;
    const listeners = this.#listeners.get(node);
    if (!listeners) return;
    for (const [name, listener] of listeners) {
      node.removeEventListener(name, listener.callback);
    }
    this.#listeners.delete(node);
  }

  // Forgets the node and every node below it.
  deleteNode(id: string) {
    const node = this.#nodes[id];
    if (!node) return;
    delete this.#nodes[id];
    const nodeInfo = this.getNodeInfo(node);
    this.#removeListeners(node);
    this.#nodeInfo.delete(node);
    if (nodeInfo) {
      nodeInfo.childIds.forEach((childId) => this.deleteNode(childId));
    }
  }

  setNode(id: string, node: Node) {
    this.#nodes[id] = node;
    const nodeInfo: NodeInfo = { id, childIds: [] };
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

  findNode(id: string): Node | undefined {
    return this.#nodes[id];
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

export type { NodeInfo };
