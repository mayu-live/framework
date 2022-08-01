// import logger from "./logger";
const logger = console

export type IdNode = { id: number; ch?: [IdNode] };
type CacheEntry = { node: Node; childIds: Set<number> };

type InsertPatch = {
  type: "insert";
  parent: number;
  before?: number;
  after?: number;
  html: string;
  ids: any;
};

type RemovePatch = { type: "remove"; id: number };

type MovePatch = {
  type: "move";
  parent: number;
  id: number;
  before?: number;
  after?: number;
};

type TextPatch = { type: "text"; id: number; text: string };

type SetAttributePatch = {
  type: "set_attribute";
  id: number;
  name: string;
  value: string;
};

export type Patch =
  | InsertPatch
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
        this.insert(patch)
        return
      }
      case "move": {
        this.move(patch)
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

  insert({parent, before, after, ids, html}: InsertPatch) {
    logger.group(`Trying to insert html into`, parent);

    const parentEntry = this.#getEntry(parent);
    const referenceId = before || after
    const referenceEntry = referenceId && this.#cache.get(referenceId);

    const body = new DOMParser().parseFromString(
      `${html}`,
      "text/html"
    ).body;

    console.log(`BODY TO INSERT`, body.innerHTML)

    const children = Array.from(body.childNodes).reverse();

    const idsArray = [ids].flat();

    idsArray.forEach((idTreeNode, i) => {
      parentEntry.childIds.add(idTreeNode.i)
      const entry = this.#cache.get(idTreeNode.i);
      const node = entry?.node || children[i];
      const ref =
        referenceEntry
          ? after
          ? referenceEntry.node.nextSibling
          : referenceEntry.node
          : null;

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

  move({id, parent, before, after}: MovePatch) {
    const entry = this.#getEntry(id);
    const parentEntry = this.#getEntry(parent);
    const refId = before || after
    const refEntry = refId && this.#cache.get(refId);

    const ref =
      refEntry
        ? after
        ? refEntry.node
        : refEntry.node
        : null;



        console.log('Moving', entry.node.textContent, before ? 'before' : after ? 'after' : 'last', (ref?.textContent || parentEntry.node.__mayu.id))
    console.log({before, after})
    console.log(ref?.textContent)

    parentEntry.node.insertBefore(entry.node, ref);
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
    if (!node) {
      console.error(idTreeNode)
      throw new Error('No node found for idTreeNode')
    }
    const childIds = new Set((idTreeNode.ch || []).map((child) => child.id));

    this.#removeRecursiveFromCache(idTreeNode.id);

    this.#cache.set(idTreeNode.id, { node, childIds });
    node.__mayu = { id: idTreeNode.id };

    logger.group("Add to cache", idTreeNode.id, "type", node.nodeName);

    // logger.log('Updating cache for', node, 'with id', idTreeNode.i)

    let i = 0;
    const ch = idTreeNode.ch || [];

    node.childNodes.forEach((childNode) => {
      if (this.isIgnoredNode(childNode)) {
        logger.warn(`Ignored:`, childNode);
        return;
      }

      const childIdNode = ch[i++];

      if (!childIdNode) {
        logger.error(
          `No childIdNode at index`,
          i,
          "on node",
          null,
          "with parent id",
          idTreeNode.id,
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
