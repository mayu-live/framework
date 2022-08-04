function isUndef(v) {
  return v === undefined || v === null;
}

const nodeOps = {
  insertBefore(parentElm, oldEndVnode, oldStartVnode) {
    console.log("moving", oldEndVnode, "before", oldStartVnode);
  },
  insertAfter(parentElm, oldEndVnode, oldStartVnode) {
    console.log("moving", oldEndVnode, "after", oldStartVnode);
  },
};

function isDef(v) {
  return !isUndef(v);
}

function updateChildren(
  parentElm,
  oldCh,
  newCh,
  insertedVnodeQueue,
  removeOnly
) {
  let oldStartIdx = 0;
  let newStartIdx = 0;
  let oldEndIdx = oldCh.length - 1;
  let oldStartVnode = oldCh[0];
  let oldEndVnode = oldCh[oldEndIdx];
  let newEndIdx = newCh.length - 1;
  let newStartVnode = newCh[0];
  let newEndVnode = newCh[newEndIdx];
  let oldKeyToIdx, idxInOld, vnodeToMove, refElm;

  // removeOnly is a special flag used only by <transition-group>
  // to ensure removed elements stay in correct relative positions
  // during leaving transitions
  const canMove = !removeOnly;

  while (oldStartIdx <= oldEndIdx && newStartIdx <= newEndIdx) {
    if (isUndef(oldStartVnode)) {
      oldStartVnode = oldCh[++oldStartIdx]; // Vnode has been moved left
    } else if (isUndef(oldEndVnode)) {
      oldEndVnode = oldCh[--oldEndIdx];
    } else if (sameVnode(oldStartVnode, newStartVnode)) {
      patchVnode(
        oldStartVnode,
        newStartVnode,
        insertedVnodeQueue,
        newCh,
        newStartIdx
      );
      oldStartVnode = oldCh[++oldStartIdx];
      newStartVnode = newCh[++newStartIdx];
    } else if (sameVnode(oldEndVnode, newEndVnode)) {
      patchVnode(
        oldEndVnode,
        newEndVnode,
        insertedVnodeQueue,
        newCh,
        newEndIdx
      );
      oldEndVnode = oldCh[--oldEndIdx];
      newEndVnode = newCh[--newEndIdx];
    } else if (sameVnode(oldStartVnode, newEndVnode)) {
      // Vnode moved right
      patchVnode(
        oldStartVnode,
        newEndVnode,
        insertedVnodeQueue,
        newCh,
        newEndIdx
      );
      canMove && nodeOps.insertAfter(parentElm, oldStartVnode, oldEndVnode);
      oldStartVnode = oldCh[++oldStartIdx];
      newEndVnode = newCh[--newEndIdx];
    } else if (sameVnode(oldEndVnode, newStartVnode)) {
      // Vnode moved left
      patchVnode(
        oldEndVnode,
        newStartVnode,
        insertedVnodeQueue,
        newCh,
        newStartIdx
      );
      canMove &&
        nodeOps.insertBefore(parentElm, oldEndVnode.elm, oldStartVnode.elm);
      oldEndVnode = oldCh[--oldEndIdx];
      newStartVnode = newCh[++newStartIdx];
    } else {
      if (isUndef(oldKeyToIdx))
        oldKeyToIdx = createKeyToOldIdx(oldCh, oldStartIdx, oldEndIdx);
      idxInOld = isDef(newStartVnode.key)
        ? oldKeyToIdx[newStartVnode.key]
        : findIdxInOld(newStartVnode, oldCh, oldStartIdx, oldEndIdx);
      if (isUndef(idxInOld)) {
        // New element
        createElm(
          newStartVnode,
          insertedVnodeQueue,
          parentElm,
          oldStartVnode,
          false,
          newCh,
          newStartIdx
        );
      } else {
        vnodeToMove = oldCh[idxInOld];
        if (sameVnode(vnodeToMove, newStartVnode)) {
          patchVnode(
            vnodeToMove,
            newStartVnode,
            insertedVnodeQueue,
            newCh,
            newStartIdx
          );
          console.log(`Clearing index`, idxInOld);
          oldCh[idxInOld] = undefined;
          canMove &&
            nodeOps.insertBefore(parentElm, vnodeToMove.elm, oldStartVnode.elm);
        } else {
          // same key but different element. treat as new element
          createElm(
            newStartVnode,
            insertedVnodeQueue,
            parentElm,
            oldStartVnode,
            false,
            newCh,
            newStartIdx
          );
        }
      }
      newStartVnode = newCh[++newStartIdx];
    }
  }
  if (oldStartIdx > oldEndIdx) {
    refElm = isUndef(newCh[newEndIdx + 1]) ? null : newCh[newEndIdx + 1].elm;
    addVnodes(
      parentElm,
      refElm,
      newCh,
      newStartIdx,
      newEndIdx,
      insertedVnodeQueue
    );
  } else if (newStartIdx > newEndIdx) {
    removeVnodes(oldCh, oldStartIdx, oldEndIdx);
  }
}

function patchVnode(
  vnode,
  newStartVnode,
  insertedVnodeQueue,
  newCh,
  newStartIdx
) {
  console.log("patching vnode", vnode, "with", newStartVnode);
}

function checkDuplicateKeys(children) {
  const seenKeys = {};
  for (let i = 0; i < children.length; i++) {
    const vnode = children[i];
    const key = vnode.key;
    if (isDef(key)) {
      if (seenKeys[key]) {
        warn(
          `Duplicate keys detected: '${key}'. This may cause an update error.`,
          vnode.context
        );
      } else {
        seenKeys[key] = true;
      }
    }
  }
}

function createKeyToOldIdx(children, beginIdx, endIdx) {
  let i, key;
  const map = {};
  for (i = beginIdx; i <= endIdx; ++i) {
    key = children[i].key;
    if (isDef(key)) map[key] = i;
  }
  return map;
}

function findIdxInOld(node, oldCh, start, end) {
  for (let i = start; i < end; i++) {
    const c = oldCh[i];
    if (isDef(c) && sameVnode(node, c)) return i;
  }
}

function sameVnode(a, b) {
  return a.key === b.key && a.type === b.type;
}

function addVnodes(
  parentElm,
  refElm,
  newCh,
  newStartIdx,
  newEndIdx,
  insertedVnodeQueue
) {
  console.log(
    "adding vnodes",
    newStartIdx,
    newEndIdx,
    newCh.slice(newStartIdx, newEndIdx + 1)
  );
}

function removeVnodes(oldCh, oldStartIdx, oldEndIdx) {
  console.log(
    "removing vnodes",
    oldStartIdx,
    oldEndIdx,
    oldCh.slice(oldStartIdx, oldEndIdx + 1)
  );
}

function createElm(
  newStartVnode,
  insertedVnodeQueue,
  parentElm,
  refElm,
  idk,
  newCh,
  newStartIdx
) {
  console.log("Creating ", newStartVnode, "before", refElm);
}

const oldCh = [
  { key: 1, name: "one" },
  { key: 2, name: "two" },
  { key: 3, name: "three" },
  { key: null, name: "four" },
  { key: null, name: "five" },
];
const newCh = [
  { key: 2, name: "two" },
  { key: 3, name: "three" },
  { key: null, name: "four" },
  { key: 1, name: "one" },
];
const insertedNodeQueue = [];

updateChildren(null, oldCh, newCh, insertedNodeQueue);
