import type NodeRegistry from "./node-registry";
import type { NodeInfo } from "./node-registry";

function updateHead(
  registry: NodeRegistry,
  element: Element,
  nodeInfo: NodeInfo,
  newChildIds: string[],
) {
  const oldChildIds = nodeInfo.childIds;

  const existingNodes = new Map();

  oldChildIds.forEach((id, i) => {
    existingNodes.set(id, element.childNodes[i]);
  });

  newChildIds.forEach((id) => {
    existingNodes.set(id, registry.getNode(id));
  });

  // Remove nodes that are no longer needed
  oldChildIds.forEach((id) => {
    if (newChildIds.includes(id)) return;
    if (!existingNodes.has(id)) return;
    const nodeToRemove = existingNodes.get(id);
    if (!nodeToRemove) return;
    element.removeChild(nodeToRemove);
    existingNodes.delete(id); // Ensure to remove from the map as well
    registry.deleteNode(id);
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
      node = registry.getNode(id) as Element; // Assuming registry.getNode(id) returns an Element or Node

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

type MoveBeforeElement = Element & {
  moveBefore: (node: Element | CharacterData, child: Node | null) => void;
};

function canMoveBefore(element: Element): element is MoveBeforeElement {
  return typeof (element as MoveBeforeElement).moveBefore === "function";
}

function replaceChildrenWithMoves(
  element: MoveBeforeElement,
  children: Node[],
) {
  let cursor = element.firstChild;

  for (const child of children) {
    if (child === cursor) {
      cursor = cursor.nextSibling;
      continue;
    }

    if (child.parentNode === element) {
      // moveBefore preserves state that insertBefore loses when moving an
      // already-connected node, such as focus, transitions, and iframe loads.
      element.moveBefore!(child as Element | CharacterData, cursor);
    } else {
      // New children are disconnected, which moveBefore intentionally rejects.
      element.insertBefore(child, cursor);
    }

    cursor = child.nextSibling;
  }

  // Keep ReplaceChildren's contract: discard any untracked DOM children too.
  while (cursor) {
    const next = cursor.nextSibling;
    element.removeChild(cursor);
    cursor = next;
  }
}

// Makes the element hold exactly the given children, in order. Nodes that
// are no longer children are forgotten.
export function replaceChildren(
  registry: NodeRegistry,
  id: string,
  childIds: string[],
) {
  const element = registry.getElement(id);
  const nodeInfo = registry.getNodeInfo(element);

  if (nodeInfo) {
    if (element.nodeName === "HEAD") {
      updateHead(registry, element, nodeInfo, childIds);
      return;
    }

    nodeInfo.childIds.forEach((id) => {
      if (!childIds.includes(id)) {
        registry.deleteNode(id);
      }
    });
  }

  const children = registry.getNodes(childIds);

  if (canMoveBefore(element)) {
    replaceChildrenWithMoves(element, children);
  } else {
    // Safari does not yet support moveBefore. Keep the previous, fully
    // compatible behavior there.
    element.replaceChildren(...children);
  }

  if (nodeInfo) nodeInfo.childIds = childIds;

  whenIdle(() => {
    handleAutofocus(element);
  });
}

// Safari has no requestIdleCallback.
function whenIdle(callback: () => void) {
  if (typeof requestIdleCallback === "function") {
    requestIdleCallback(callback);
  } else {
    setTimeout(callback, 0);
  }
}

// Any focusable element can carry autofocus: inputs, textareas, selects,
// buttons and contenteditable elements alike.
function handleAutofocus(node: Node) {
  if (node instanceof HTMLElement && node.autofocus) {
    node.focus();
    return;
  }

  for (const child of node.childNodes) {
    handleAutofocus(child);
  }
}
