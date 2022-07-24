export default function (parentNode, newCh, oldCh) {
  // Before
  let oldStartIndex = 0;
  // New front
  let newStartIndex = 0;
  // Old queen
  let oldEndIndex = oldCh.length - 1;
  // New post
  let newEndIndex = newCh.length - 1;
  // Old nodes
  let oldStartVnode = oldCh[oldStartIndex];
  // Old back node
  let oldEndVnode = oldCh[oldEndIndex];
  // New front node
  let newStartVnode = newCh[newStartIndex];
  // New back node
  let newEndVnode = newCh[newEndIndex];
  // In the above four cases, it is the structure used in hit processing
  let keyMap = null;
  // Loop through processing nodes
  while (oldStartIndex <= oldEndIndex && newStartIndex <= newEndIndex) {
    // The first is not to judge the first four hits , But to skip what has been added undefined Things marked
    if (oldStartVnode === undefined) {
      oldStartVnode = oldCh[++oldStartIndex];
    } else if (oldEndVnode === undefined) {
      oldEndVnode = oldCh[--oldEndIndex];
    } else if (newStartVnode === undefined) {
      newStartVnode = newCh[++newStartIndex];
    } else if (newEndVnode === undefined) {
      newEndVnode = newCh[--newEndIndex];
    } else if (checkSameVnode(oldStartVnode, newStartVnode)) {
      // New and old
      patchVnode(oldStartVnode, newStartVnode);
      oldStartVnode = oldCh[++oldStartIndex];
      newStartVnode = newCh[++newStartIndex];
    } else if (checkSameVnode(oldEndVnode, newEndVnode)) {
      // New post and old post hit
      patchVnode(oldEndVnode, newEndVnode);
      oldEndVnode = oldCh[--oldEndIndex];
      newEndVnode = newCh[--newEndIndex];
    } else if (checkSameVnode(oldStartVnode, newEndVnode)) {
      // New and old hits
      patchVnode(oldStartVnode, newEndVnode);
      // When the old hits the new , At this time, we need to move the node . Move the node pointed to before the new node to the back of the old node
      // How to move nodes ？？ As long as you insert one already in DOM Nodes on the tree , It will be moved
      parentNode.insertBefore(oldStartVnode.elm, oldEndVnode.elm.nextSibling);
      oldStartVnode = oldCh[++oldStartIndex];
      newEndVnode = newCh[--newEndIndex];
    } else if (checkSameVnode(oldEndVnode, newStartVnode)) {
      // New before and old after hit
      patchVnode(oldEndVnode, newStartVnode);
      // When the new front and old back hit , At this time, we need to move the node . Move the node pointed by the new node to the front of the old node
      parentNode.insertBefore(oldEndVnode.elm, oldStartVnode.elm);
      oldEndVnode = oldCh[--oldEndIndex];
      newStartVnode = newCh[++newStartIndex];
    } else {
      // None of the four hits hit
      // Make keyMap A mapping object , So you don't have to traverse the old object every time .
      console.log(oldEndVnode, newEndVnode);
      if (!keyMap) {
        keyMap = {};
        // from oldStartIdx Start , To oldEndIdx end , establish keyMap Mapping objects
        for (let i = oldStartIndex; i <= oldEndIndex; i++) {
          // from oldStartIdx Start , To oldEndIdx end , establish keyMap Mapping objects
          const key = oldCh[i].data.key;
          if (key != undefined) {
            keyMap[key] = i;
          }
        }
      }
      // Look for the current （newStartIdx） This is in the keyMap The position number of the map in
      const index = keyMap[newStartVnode.key];
      if (index === undefined) {
        // Judge , If idxInOld yes undefined Indicates that it is a brand new item
        // Added items （ Namely newStartVnode the ) It's not really DOM node
        parentNode.insertBefore(createEle(newStartVnode), oldStartVnode.elm);
      } else {
        // If not undefined, Not a new item , But to move
        const eleToMove = old[index];
        patchVnode(eleToMove, newStartVnode);
        // Set this to undefined, It means that I have finished this
        oldCh[index] = undefined;
        // Move , call insertBefore It can also be mobile .
        parentNode.insertBefore(eleToMove.elm, oldStartVnode.elm);
      }
      // The pointer moves down , Just move the new head
      newStartVnode = newCh[++newStartIndex];
    }
  }
  // Go ahead and see if there's any left . The cycle is over start It's better than old Small
  if (newStartIndex <= newEndIndex) {
    // Traverse the new newCh, Add to the old ones that haven't been processed
    for (let i = newStartIndex; i <= newEndIndex; i++) {
      // insertBefore Methods can automatically identify null, If it is null It'll automatically line up at the end of the line . and appendChild It's the same .
      // newCh[i] There is no real DOM, So call createElement() The function becomes DOM
      parentNode.insertBefore(createEle(newCh[i]), oldCh[oldStartIndex].elm);
    }
  } else if (oldStartIndex <= oldEndIndex) {
    // Batch deletion oldStart and oldEnd Items between pointers
    for (let i = oldStartIndex; i <= oldEndIndex; i++) {
      if (oldCh[i]) {
        parentNode.removeChild(oldCh[i].elm);
      }
    }
  }
}
