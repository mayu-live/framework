type IdTreeNodeWithChildren = [number, IdTreeNode[]];
type IdTreeNodeWithoutChildren = number;
type IdTreeNode = IdTreeNodeWithChildren | IdTreeNodeWithoutChildren;

class NodeTreeNode {
  id: number;
  children: NodeTreeNode[];
  element: ChildNode;

  constructor(node: IdTreeNode, element: ChildNode, parent?: ChildNode) {
    if (!node) {
      console.error(
        "There is no tree node for element",
        element,
        "with parent",
        parent
      );
      console.log(Array.from(parent?.childNodes || []));
      throw new Error("Tree node not found for element");
    }

    if (!element) {
      console.error(
        "There is no element for node",
        node,
        "with parent",
        parent
      );
      console.log(Array.from(parent?.childNodes || []));
      throw new Error("Element not found for node");
    }

    this.element = element;

    if (typeof node === "number") {
      this.id = node;
      console.log(node, element);
      this.children = [];
    } else {
      this.id = node[0];
      console.log(node[0], element);
      const childNodes = Array.from(element.childNodes).filter((node) => {
        if (node.nodeType == node.TEXT_NODE) return true;
        if (node.nodeType == node.COMMENT_NODE) {
          console.log(node);
          return true;
        }
        if (node.nodeType == node.ELEMENT_NODE) {
          if ((node as HTMLElement).dataset.mayuId !== undefined) {
            return true;
          }
        }

        return false;
      });
      this.children = node[1].map(
        (child, i) => new NodeTreeNode(child, childNodes[i], element)
      );
    }
  }

  remove(nodeId: number) {
    if (nodeId === undefined) return
    let found = false;
    // console.log(
    //   "trying to remove", nodeId
    // )

    this.children = this.children.filter((child) => {
      // console.log(child.id, nodeId)
      if (child.id !== nodeId) return true;

      console.error("removing", child.id, "from", this.id);
      this.element.removeChild(child.element);

      found = true;

      return false;
    });

    if (found) return;

    this.children.forEach((child) => child.remove(nodeId));
  }

  insertBefore(parentId: number, referenceId: number, html: string, ids: any) {
    let found = false;

    if (parentId === this.id) {
      found = true;

      const referenceIndex = this.children.findIndex(
        (child) => child.id === referenceId
      );

      const children = Array.from((new DOMParser()).parseFromString(html, 'text/html').body.childNodes)

      if (referenceIndex >= 0) {
        for (let child of children.reverse()) {
          this.element.insertBefore(child, this.children[referenceIndex].element)
          this.children.splice(
            referenceIndex,
            0,
            new NodeTreeNode(ids, this.element.childNodes[referenceIndex - 1])
          )
        }
      } else {
        for (let child of children) {
          this.children.push(new NodeTreeNode(ids, this.element.appendChild(child)))
        }
      }
    }

    if (found) return;

    this.children.forEach((child) =>
      child.insertBefore(parentId, referenceId, html, ids)
    );
  }
}

class NodeTree {
  root: NodeTreeNode;

  constructor(idTreeRoot: IdTreeNode) {
    this.root = new NodeTreeNode(idTreeRoot, document.documentElement);
    console.log(this.root);
  }

  insertBefore(parentId: number, referenceId: number, html: string, ids: any) {
    this.remove(ids[0]);
    this.root.insertBefore(parentId, referenceId, html, ids);
  }

  remove(nodeId: number) {
    if (!nodeId) return
    console.log('Trying to remove', nodeId)
    this.root.remove(nodeId);
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
type Patch = InsertBeforePatch | RemovePatch;

class Mayu {
  readonly sessionId: string;
  readonly connection: EventSource;
  readonly nodeTree: NodeTree;

  constructor(sessionId: string, idTreeRoot: IdTreeNode) {
    this.sessionId = sessionId;
    this._updateHTML = this._updateHTML.bind(this);
    this._applyPatches = this._applyPatches.bind(this);
    this.nodeTree = new NodeTree(idTreeRoot);

    this.connection = new EventSource(`/__mayu/events/${this.sessionId}`);

    this.connection.onerror = (e) => {
      console.log(e);
      console.error("Connection error.");
    };

    // this.connection.addEventListener("html", this._updateHTML);
    this.connection.addEventListener("patch_set", this._applyPatches);
  }

  handle(e: Event, handlerId: string) {
    e.preventDefault();

    const payload = {
      type: e.type,
    };

    fetch(`/__mayu/handler/${this.sessionId}/${handlerId}`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      body: JSON.stringify({ payload }),
    });
  }

  _updateHTML({ data }: MessageEvent) {
    const html = JSON.parse(data)
      .replace(/^<html.*?>/, "")
      .replace(/<\/html>$/, "");
    document.documentElement.innerHTML = html;
  }

  _applyPatches({ data }: MessageEvent) {
    const { patch_set: patches } = JSON.parse(data) as { patch_set: Patch[] };

    for (const patch of patches) {
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
      }
    }
  }
}

export default Mayu;
