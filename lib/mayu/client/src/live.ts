type IdNode = { i: number; c?: [IdNode] };
type CacheEntry = { node: Node; childIds: number[] };

function createSilentLogger() {
  const noop = (..._args: any[]) => {}

  return {
    info: noop,
    log: noop,
    warn: noop,
    error: noop,
    group: noop,
    groupEnd: noop,
  }
}

function createLogger() {
  return {
    info: console.info.bind(console),
    log: console.log.bind(console),
    error: console.error.bind(console),
    warn: console.warn.bind(console),
    group: console.group.bind(console),
    groupEnd: console.groupEnd.bind(console),
  }
}

const logger = console //createSilentLogger()

class NodeTree {
  #cache = new Map<number, CacheEntry>();

  constructor(root: IdNode) {
    logger.log(root)
    this.updateCache(document.documentElement, root);

    (window as any).mayuCache = this.#cache
  }

  updateText(id: number, text: string) {
    const node = this.#getEntry(id).node

    if (node.nodeType !== node.TEXT_NODE) {
      console.error(node)
      throw new Error("Trying to update text on a non text node")
    }

    node.textContent = text
  }

  setAttribute(id: number, name: string, value: string) {
    const node = this.#getEntry(id).node as Element;

    console.log("Trying to set attribute", name, value)

    if (node instanceof HTMLInputElement) {
      if (name === 'value') {
        node.value = value
        return
      }
    }

    if (name === 'initial_value') {
      name = 'value'
    } else {
      name = name.replaceAll(/_/g, '')
    }

    node.setAttribute(name, value)
  }

  insertBefore(
    parentId: number,
    referenceId: number,
    html: string,
    ids: IdNode[]
  ) {
    logger.group(`Trying to insert html into`, parentId)
    const parentEntry = this.#getEntry(parentId)

    const referenceEntry = this.#cache.get(referenceId);
    const body = new DOMParser().parseFromString(`<body>${html}</body>`, "text/html").body
    logger.log({body})
    const children = Array.from(body.childNodes).reverse();

    const idsArray = [ids].flat();
    parentEntry.childIds = parentEntry.childIds.concat(
      idsArray.map(({ i }) => i)
    );

    logger.log({children, html})

    idsArray.forEach((idTreeNode, i) => {
      this.remove(idTreeNode.i)

      const node = children[i]
      const ref = referenceEntry ? referenceEntry.node : null
      logger.log({ parent: parentEntry.node, node, ref })
      const insertedNode = parentEntry.node.insertBefore(node, ref);
      this.updateCache(insertedNode, idTreeNode);
    });

    logger.groupEnd()
  }

  #getEntry(id: number) {
    const entry = this.#cache.get(id);

    if (!entry) {
      logger.error("Could not find", id, "in cache!");
      logger.error(Array.from(this.#cache.keys()))
      throw new Error(`Could not find ${id} in cache!`);
    }

    return entry;
  }

  remove(nodeId: number) {
    logger.info("Trying to remove", nodeId);

    try {
      const entry = this.#getEntry(nodeId);
      const parentNode = entry.node.parentNode;

      if (parentNode) {
        const parentId = parentNode.__mayu.id;
        const parentEntry = this.#cache.get(parentId);

        parentNode.removeChild(entry.node);

        if (parentEntry) {
          parentEntry.childIds = parentEntry.childIds.filter(
            (id) => id !== nodeId
          );
        }
      } else {
        logger.warn(`Node`, entry.node, "has no parent??");
      }

      this.#removeRecursiveFromCache(nodeId);
    } catch (e) {
      logger.warn(e)
    }
  }

  #removeRecursiveFromCache(id: number) {
    const entry = this.#cache.get(id);

    if (!entry) return;

    logger.group('Removing from cache', id)

    this.#cache.delete(id);

    entry.childIds.forEach((childId) => {
      this.#removeRecursiveFromCache(childId);
    });

    logger.groupEnd()
  }

  isAcceptableNode(node: Node) {
    if (node.nodeType == node.TEXT_NODE) return true
    if (node.nodeType == node.COMMENT_NODE) return true
    if (node.nodeType == node.ELEMENT_NODE) {
      const dataset = (node as HTMLElement).dataset;
      if (typeof dataset.mayuId === 'string') return true
    }

    return false
  }

  updateCache(node: Node, idTreeNode: IdNode) {
    const childIds = (idTreeNode.c || []).map((child) => child.i);
    this.#cache.set(idTreeNode.i, { node, childIds });
    node.__mayu = { id: idTreeNode.i };

    logger.group('Add to cache', idTreeNode.i, 'type', node.nodeName)

    // logger.log('Updating cache for', node, 'with id', idTreeNode.i)

    let i = 0;
    const c = idTreeNode.c || []

    node.childNodes.forEach((childNode) => {
      if (!this.isAcceptableNode(childNode)) {
        logger.warn(`Not acceptable:`, childNode)
        return
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
          childNode,
        );
        return;
      }

      this.updateCache(childNode, childIdNode);
    });

    logger.groupEnd()
  }
}

/*
if('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/__mayu/sw.js');
};
*/

type InsertBeforePatch = {
  type: "insert_before";
  parent_id: number;
  reference_id: number;
  html: string;
  ids: any;
};
type RemovePatch = { type: "remove_node"; id: number };
type UpdateTextPatch = { type: "update_text"; id: number, text: string };
type SetAttributePatch = { type: "set_attribute"; id: number, name: string, value: string };
type Patch = InsertBeforePatch | RemovePatch | UpdateTextPatch | SetAttributePatch;

class Mayu {
  readonly sessionId: string;
  readonly connection: EventSource;
  readonly nodeTree: NodeTree;
  readonly queue = <MessageEvent[]>[]

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
      this._applyPatches(e)
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
    logger.info('APPLYING PATCHES')
    const { patch_set: patches } = JSON.parse(data) as { patch_set: Patch[] };

    for (const patch of patches.reverse()) {
      switch (patch.type) {
        case "insert_before": {
          this.nodeTree.insertBefore(
            patch.parent_id,
            patch.reference_id,
            patch.html,
            patch.ids
          );
          break;
        }
        case "remove_node": {
          this.nodeTree.remove(patch.id);
          break;
        }
        case "update_text": {
          this.nodeTree.updateText(patch.id, patch.text)
          break
        }
        case "set_attribute": {
          this.nodeTree.setAttribute(patch.id, patch.name, patch.value)
          break
        }
      }
    }
  }
}

export default Mayu;
