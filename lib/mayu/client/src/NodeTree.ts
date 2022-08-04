import logger from "./logger.js";

export type IdNode = { id: number; ch?: [IdNode]; type: string };
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

type StylePatch = { type: "css"; id: number; attr: string; value?: string };
type StylesheetPatch = { type: "stylesheet"; paths: string[] };

type AddTextPatch = { type: "text"; id: number; text: string };
type AppendTextPatch = { type: "text"; id: number; append: string };
type TextPatch = AddTextPatch | AppendTextPatch;

type AttributePatch = {
  type: "attr";
  id: number;
  name: string;
  value?: string;
};

export type Patch =
  | InsertPatch
  | MovePatch
  | RemovePatch
  | TextPatch
  | AttributePatch
  | StylePatch
  | StylesheetPatch;

function cloneScriptElement(element: HTMLScriptElement) {
  const script = document.createElement("script");
  script.text = element.innerHTML;
  for (const attr of element.attributes) {
    console.log("Setting attribute", attr.name, "to", attr.value);
    script.setAttribute(attr.name, attr.value);
  }
  return script;
}

function replaceScriptNodes(parent: Node, node: Node) {
  if ((node as Element).tagName === "SCRIPT") {
    parent.replaceChild(cloneScriptElement(node as HTMLScriptElement), node);
    return;
  }

  for (const child of node.childNodes) {
    replaceScriptNodes(node, child);
  }
}

class NodeTree {
  #cache = new Map<number, CacheEntry>();

  constructor(root: IdNode, element = document.documentElement) {
    this.updateCache(element, root);
    //console.log(JSON.stringify(root, null, 2))
  }

  apply(patches: Patch[]) {
    for (const patch of patches) {
      this.applyPatch(patch);
    }
  }

  applyPatch(patch: Patch) {
    switch (patch.type) {
      case "insert": {
        this.insert(patch);
        return;
      }
      case "move": {
        this.move(patch);
        break;
      }
      case "remove": {
        this.remove(patch.id);
        break;
      }
      case "css": {
        const element = this.#getEntry(patch.id).node as HTMLElement;

        if (patch.value) {
          element.style.setProperty(patch.attr, patch.value);
        } else {
          element.style.removeProperty(patch.attr);
        }
      }
      case "text": {
        if ("text" in patch) {
          this.updateText(patch.id, patch.text);
        }

        if ("append" in patch) {
          this.appendText(patch.id, patch.append);
        }
        break;
      }
      case "attr": {
        if (patch.value !== undefined) {
          this.setAttribute(patch.id, patch.name, patch.value);
        } else {
          this.removeAttribute(patch.id, patch.name);
        }
        break;
      }
      case "stylesheet": {
        for (const href of patch.paths) {
          // TODO: This should be possible in Chrome, but not yet in Firefox.
          // const stylesheet = await import(path, { assert: { type: 'css' } });
          // document.adoptedStyleSheets.push(stylesheet)
          if (document.querySelector(`link[href="${href}"]`)) {
            continue;
          }

          const link = document.createElement("link");
          link.setAttribute("rel", "stylesheet");
          link.setAttribute("href", href);
          document.head.insertAdjacentElement("beforeend", link);
        }

        break;
      }
      default: {
        console.error("Unknown patch", patch);
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

  appendText(id: number, text: string) {
    const node = this.#getEntry(id).node;

    if (node.nodeType !== node.TEXT_NODE) {
      throw new Error("Trying to update text on a non text node");
    }

    node.textContent += text;
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

  removeAttribute(id: number, name: string) {
    const node = this.#getEntry(id).node as Element;
    node.removeAttribute(name);
  }

  insert({ parent, before, after, ids, html }: InsertPatch) {
    logger.group(`Trying to insert html into`, parent);

    const parentEntry = this.#getEntry(parent);
    const referenceId = before || after;
    const referenceEntry = referenceId && this.#cache.get(referenceId);

    const body = new DOMParser().parseFromString(`${html}`, "text/html").body;

    logger.log(`BODY TO INSERT`, body.innerHTML);

    const children = Array.from(body.childNodes).reverse();

    const idsArray = [ids].flat();

    idsArray.forEach((idTreeNode, i) => {
      parentEntry.childIds.add(idTreeNode.i);
      const entry = this.#cache.get(idTreeNode.i);
      const node = entry?.node || children[i];
      const ref = referenceEntry
        ? after
          ? referenceEntry.node.nextSibling
          : referenceEntry.node
        : null;

      const insertedNode = parentEntry.node.insertBefore(node, ref);

      if (entry) {
        (entry.node as HTMLElement).outerHTML = (node as HTMLElement).outerHTML;
      }

      requestIdleCallback(() => {
        replaceScriptNodes(parentEntry.node, insertedNode);
      });

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

      if (parentNode) {
        const parentId = parentNode.__MAYU_ID;
        const parentEntry = this.#cache.get(parentId);

        logger.log(`Removing child`, entry.node.textContent);
        parentNode.removeChild(entry.node);

        if (parentEntry) {
          parentEntry.childIds.delete(nodeId);
        }
      } else {
        logger.warn(`Node`, entry.node.__MAYU_ID, "has no parent??");
      }

      this.#removeRecursiveFromCache(nodeId, false);
    } catch (e) {
      logger.warn(e);
    }
  }

  move({ id, parent, before, after }: MovePatch) {
    const entry = this.#getEntry(id);
    const parentEntry = this.#getEntry(parent);
    const refId = before || after;
    const refEntry = refId && this.#cache.get(refId);

    const ref = refEntry ? (after ? refEntry.node : refEntry.node) : null;

    logger.log(
      "Moving",
      entry.node.textContent,
      before ? "before" : after ? "after" : "last",
      ref?.textContent || parentEntry.node.__MAYU_ID
    );
    logger.log({ before, after });
    logger.log(ref?.textContent);

    parentEntry.node.insertBefore(entry.node, ref);
  }

  #removeRecursiveFromCache(id: number, includeParent = false) {
    const entry = this.#cache.get(id);

    if (!entry) return;

    logger.group("Removing from cache", id);

    if (includeParent) {
      const parentEntry = this.#cache.get(entry.node.parentNode!.__MAYU_ID);
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
      logger.error(idTreeNode);
      throw new Error("No node found for idTreeNode");
    }
    const childIds = new Set((idTreeNode.ch || []).map((child) => child.id));

    this.#removeRecursiveFromCache(idTreeNode.id);

    this.#cache.set(idTreeNode.id, { node, childIds });
    node.__MAYU_ID = idTreeNode.id;

    logger.group(
      "Add to cache",
      idTreeNode.id,
      "type",
      node.nodeName,
      idTreeNode.type
    );

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

    if (i < ch.length) {
      throw new Error("hello");
    }

    logger.groupEnd();
  }
}

export default NodeTree;
