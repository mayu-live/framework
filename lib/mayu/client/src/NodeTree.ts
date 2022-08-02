// import logger from "./logger";
const logger = console

export type IdNode = { i: number; c?: [IdNode] };
type CacheEntry = { node: Node; childIds: Set<number> };

type InsertBeforePatch = {
  type: "insert";
  parent: number;
  before: number;
  html: string;
  ids: any;
};

type RemovePatch = { type: "remove"; id: number };

type MovePatch = {
  type: "move";
  parent: number;
  id: number;
  before?: number;
};

type TextPatch = { type: "text"; id: number; text: string };

type SetAttributePatch = {
  type: "set_attribute";
  id: number;
  name: string;
  value: string;
};

export type Patch =
  | InsertBeforePatch
  | MovePatch
  | RemovePatch
  | TextPatch
  | SetAttributePatch;

class NodeTree {
  #cache = new Map<number, CacheEntry>();

  constructor(root: IdNode, element = document.documentElement) {
    this.updateCache(element, root);
  }

  apply(patches: Patch[]) {
    for (const patch of patches) {
      this.applyPatch(patch)
    }
  }

  applyPatch(patch: Patch) {
    switch (patch.type) {
      case "insert": {
        this.insertBefore(
          patch.parent,
          patch.before,
          patch.html,
          patch.ids
        );
        return
      }
      case "move": {
        this.move(patch.parent, patch.id, patch.before);
        break;
      }
      case "remove": {
        this.remove(patch.id);
        break;
      }
      case "text": {
        this.updateText(patch.id, patch.text);
        break;
      }
      case "set_attribute": {
        this.setAttribute(patch.id, patch.name, patch.value);
        break;
      }
      default: {
        logger.error('Unknown patch', patch)
      }
    }
  }

  updateText(id: number, text: string) {
    const node = this.#getEntry(id).node;

    if (node.nodeType !== node.TEXT_NODE) {
      throw new Error("Trying to update text on a non text node");
    }

    node.textContent = text;
  }

  setAttribute(id: number, name: string, value: string) {
    const node = this.#getEntry(id).node as Element;

    // logger.log("Trying to set attribute", name, value);

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
      `${html}`,
      "text/html"
    ).body;
    const children = Array.from(body.childNodes).reverse();

    const idsArray = [ids].flat();

    idsArray.forEach(({ i }) => parentEntry.childIds.add(i));

    // logger.log({ children, html });

    idsArray.forEach((idTreeNode, i) => {
      const entry = this.#cache.get(idTreeNode.i);
      const node = entry?.node || children[i];
      const ref = referenceEntry ? referenceEntry.node : null;
      // logger.log({ parent: parentEntry.node, node, ref });
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

      // logger.warn("removing", entry.node);

      if (parentNode) {
        const parentId = parentNode.__mayu.id;
        const parentEntry = this.#cache.get(parentId);

        logger.log(`Removing child`, entry.node.textContent);
        parentNode.removeChild(entry.node);

        if (parentEntry) {
          parentEntry.childIds.delete(nodeId);
        }
      } else {
        logger.warn(`Node`, entry.node.__mayu.id, "has no parent??");
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

    // logger.log('inserting', nodeId, "in", parentId)

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
          null,
          "with parent id",
          idTreeNode.i,
          "and child node",
          null
        );
        return;
      }

      this.updateCache(childNode, childIdNode);
    });

    logger.groupEnd();
  }
}

export default NodeTree;
