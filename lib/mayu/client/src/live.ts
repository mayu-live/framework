type IdNode = { i: number; c?: [IdNode] };
type CacheEntry = { node: Node; childIds: Set<number> };

function createSilentLogger() {
  const noop = (..._args: any[]) => {};

  return {
    info: noop,
    log: noop,
    warn: noop,
    error: noop,
    group: noop,
    groupEnd: noop,
  };
}

function createLogger() {
  return {
    info: console.info.bind(console),
    log: console.log.bind(console),
    error: console.error.bind(console),
    warn: console.warn.bind(console),
    group: console.group.bind(console),
    groupEnd: console.groupEnd.bind(console),
  };
}

const logger = console; //createSilentLogger()

class NodeTree {
  #cache = new Map<number, CacheEntry>();

  constructor(root: IdNode) {
    logger.log(root);
    this.updateCache(document.documentElement, root);

    (window as any).mayuCache = this.#cache;
  }

  updateText(id: number, text: string) {
    const node = this.#getEntry(id).node;

    if (node.nodeType !== node.TEXT_NODE) {
      console.error(node);
      throw new Error("Trying to update text on a non text node");
    }

    node.textContent = text;
  }

  setAttribute(id: number, name: string, value: string) {
    const node = this.#getEntry(id).node as Element;

    console.log("Trying to set attribute", name, value);

    if (node instanceof HTMLInputElement) {
      if (name === "value") {
        node.value = value;
        return;
      }
    }

    if (name === "initial_value") {
      name = "value";
    } else {
      name = name.replaceAll(/_/g, "");
    }

    node.setAttribute(name, value);
  }

  insertBefore(
    parentId: number,
    referenceId: number,
    html: string,
    ids: IdNode[]
  ) {
    logger.group(`Trying to insert html into`, parentId);
    const parentEntry = this.#getEntry(parentId);

    const referenceEntry = this.#cache.get(referenceId);
    const body = new DOMParser().parseFromString(
      `<body>${html}</body>`,
      "text/html"
    ).body;
    logger.log({ body });
    const children = Array.from(body.childNodes).reverse();

    const idsArray = [ids].flat();

    idsArray.forEach(({ i }) => parentEntry.childIds.add(i));

    logger.log({ children, html });

    idsArray.forEach((idTreeNode, i) => {
      const entry = this.#cache.get(idTreeNode.i);
      const node = entry?.node || children[i];
      const ref = referenceEntry ? referenceEntry.node : null;
      logger.log({ parent: parentEntry.node, node, ref });
      const insertedNode = parentEntry.node.insertBefore(node, ref);

      if (entry) {
        (entry.node as HTMLElement).outerHTML = (node as HTMLElement).outerHTML;
      }

      this.updateCache(insertedNode, idTreeNode);
    });

    logger.groupEnd();
  }

  #getEntry(id: number) {
    const entry = this.#cache.get(id);

    if (!entry) {
      logger.error("Could not find", id, "in cache!");
      logger.error(Array.from(this.#cache.keys()));
      throw new Error(`Could not find ${id} in cache!`);
    }

    return entry;
  }

  remove(nodeId: number) {
    logger.info("Trying to remove", nodeId);

    try {
      const entry = this.#getEntry(nodeId);
      const parentNode = entry.node.parentNode;

      console.warn('removing', entry.node)

      if (parentNode) {
        const parentId = parentNode.__mayu.id;
        const parentEntry = this.#cache.get(parentId);

        console.log(`Removing child`, entry.node.textContent)
        parentNode.removeChild(entry.node);

        if (parentEntry) {
          parentEntry.childIds.delete(nodeId);
        }
      } else {
        logger.warn(`Node`, entry.node, "has no parent??");
      }

      this.#removeRecursiveFromCache(nodeId, false);
    } catch (e) {
      logger.warn(e);
    }
  }

  move(parentId: number, nodeId: number, refId?: number) {
    const parentEntry = this.#getEntry(parentId);
    const entry = this.#getEntry(nodeId);
    const refEntry = this.#cache.get(refId || 0);

    parentEntry.childIds.add(nodeId);
    parentEntry.node.insertBefore(entry.node, refEntry?.node || null);
  }

  #removeRecursiveFromCache(id: number, includeParent = false) {
    const entry = this.#cache.get(id);

    if (!entry) return;

    logger.group("Removing from cache", id);

    if (includeParent) {
      const parentEntry = this.#cache.get(entry.node.parentNode!.__mayu.id);
      parentEntry?.childIds?.delete(id);
    }

    this.#cache.delete(id);

    entry.childIds.forEach((childId) => {
      this.#removeRecursiveFromCache(childId, false);
    });

    entry.childIds.delete(id);

    logger.groupEnd();
  }

  isIgnoredNode(node: Node) {
    if (node.nodeType === node.TEXT_NODE) return false;
    if (node.nodeType === node.COMMENT_NODE) return false;
    if (node.nodeType === node.ELEMENT_NODE) {
      const dataset = (node as HTMLElement).dataset;
      if (typeof dataset.mayuId === "string") return false;
    }

    return true;
  }

  updateCache(node: Node, idTreeNode: IdNode) {
    const childIds = new Set((idTreeNode.c || []).map((child) => child.i));

    this.#removeRecursiveFromCache(idTreeNode.i);

    this.#cache.set(idTreeNode.i, { node, childIds });
    node.__mayu = { id: idTreeNode.i };

    logger.group("Add to cache", idTreeNode.i, "type", node.nodeName);

    // logger.log('Updating cache for', node, 'with id', idTreeNode.i)

    let i = 0;
    const c = idTreeNode.c || [];

    node.childNodes.forEach((childNode) => {
      if (this.isIgnoredNode(childNode)) {
        logger.warn(`Ignored:`, childNode);
        return;
      }

      const childIdNode = c[i++];

      if (!childIdNode) {
        logger.error(
          `No childIdNode at index`,
          i,
          "on node",
          node,
          "with parent id",
          idTreeNode.i,
          "and child node",
          childNode
        );
        return;
      }

      this.updateCache(childNode, childIdNode);
    });

    logger.groupEnd();
  }
}

/*
if('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/__mayu/sw.js');
};
*/

type InsertBeforePatch = {
  type: "insert";
  parent_id: number;
  before_id?: number;
  html: string;
  ids: any;
};
type RemovePatch = { type: "remove"; id: number };
type MovePatch = {
  type: "move";
  parent_id: number;
  id: number;
  before_id?: number;
};
type UpdateTextPatch = { type: "update_text"; id: number; text: string };
type SetAttributePatch = {
  type: "set_attribute";
  id: number;
  name: string;
  value: string;
};
type Patch =
  | InsertBeforePatch
  | MovePatch
  | RemovePatch
  | UpdateTextPatch
  | SetAttributePatch;

class Mayu {
  readonly sessionId: string;
  readonly connection: EventSource;
  readonly nodeTree: NodeTree;
  readonly queue = <MessageEvent[]>[];

  constructor(sessionId: string, idTreeRoot: IdNode) {
    this.sessionId = sessionId;
    this._updateHTML = this._updateHTML.bind(this);
    this._applyPatches = this._applyPatches.bind(this);
    this.nodeTree = new NodeTree(idTreeRoot);

    this.connection = new EventSource(`/__mayu/events/${this.sessionId}`);

    this.connection.onerror = (e) => {
      logger.log(e);
      logger.error("Connection error.");
    };

    // this.connection.addEventListener("html", this._updateHTML);
    this.connection.addEventListener("patch_set", (e) => {
      this._applyPatches(e);
    });
  }

  handle(e: Event, handlerId: string) {
    e.preventDefault();

    const payload = {
      type: e.type,
      value: (e.target as any).value,
    };

    fetch(`/__mayu/handler/${this.sessionId}/${handlerId}`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    });
  }

  _updateHTML({ data }: MessageEvent) {
    const html = JSON.parse(data)
      .replace(/^<html.*?>/, "")
      .replace(/<\/html>$/, "");
    document.documentElement.innerHTML = html;
  }

  _applyPatches({ data }: MessageEvent) {
    logger.info("APPLYING PATCHES");
    const { patch_set: patches } = JSON.parse(data) as { patch_set: Patch[] };

    for (const patch of patches) {
      switch (patch.type) {
        case "insert": {
          this.nodeTree.insertBefore(
            patch.parent_id,
            patch.before_id,
            patch.html,
            patch.ids
          );
          break;
        }
        case "move": {
          this.nodeTree.move(patch.parent_id, patch.id, patch.before_id);
          break;
        }
        case "remove": {
          break;
        }
        case "update_text": {
          this.nodeTree.updateText(patch.id, patch.text);
          break;
        }
        case "set_attribute": {
          this.nodeTree.setAttribute(patch.id, patch.name, patch.value);
          break;
        }
      }
    }

    for (const patch of patches) {
      if (patch.type === "remove") {
        this.nodeTree.remove(patch.id);
      }
    }
  }
}

export default Mayu;
