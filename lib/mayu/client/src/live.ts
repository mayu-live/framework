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
      console.log(Array.from(parent?.childNodes || []))
      throw new Error("Tree node not found for element");
    }

    if (!element) {
      console.error(
        "There is no element for node",
        node,
        "with parent",
        parent
      );
      console.log(Array.from(parent?.childNodes || []))
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

  remove(parentId: number, nodeId: number) {
    if (this.id === parentId) {
      this.children = this.children.filter((child) => {
        if (child.id !== nodeId) return true;

        console.log("removing", child.id, "from", this.id);
        this.element.removeChild(child.element);

        return false;
      });

      return;
    }

    this.children.forEach((child) => child.remove(parentId, nodeId));
  }
}

class NodeTree {
  root: NodeTreeNode;

  constructor(idTreeRoot: IdTreeNode) {
    this.root = new NodeTreeNode(idTreeRoot, document.documentElement);
    console.log(this.root);
  }

  remove(parentId: number, nodeId: number) {
    this.root.remove(parentId, nodeId);
  }
}

/*
if('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/__mayu/sw.js');
};
*/

type InsertPatch = ["insert", number, number | null, string, any];
type RemovePatch = ["remove", number, number];
type Patch = InsertPatch | RemovePatch;

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

    this.connection.addEventListener("html", this._updateHTML);
    // this.connection.addEventListener("patch_set", this._applyPatches);
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
    const patches = JSON.parse(data) as Patch[];

    for (const patch of patches) {
      switch (patch[0]) {
        case "insert": {
          //_insert(parentId: number, refNode: number | null, html: string, idTree: any) {
          break;
        }
        case "remove": {
          this.nodeTree.remove(patch[1], patch[2]);
          break;
        }
      }
    }
  }
}

export default Mayu;
