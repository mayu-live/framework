def update_children(old_ch, new_ch)
  old_start_idx = 0
  new_start_idx = 0
  old_end_idx = old_ch.length.pred
  new_end_idx = new_ch.length.pred

  while old_start_idx <= old_end_idx && new_start_idx <= new_end_idx
    old_start_vnode = old_ch[old_start_idx]
    old_start_idx += 1 unless old_start_vnode
    old_end_vnode = old_ch[old_end_idx]
    old_end_idx += 1 unless old_end_vnode
    new_start_vnode = new_ch[new_start_idx]
    new_end_vnode = new_ch[new_end_idx]

    if same?(old_start_vnode, new_start_vnode)
      patch_vnode(old_start_vnode, new_start_vnode)
      old_start_idx += 1
      new_start_idx += 1
      next
    end

    if same?(old_end_vnode, new_end_vnode)
      patch_vnode(old_end_vnode, new_end_vnode)
      old_end_idx -= 1
      new_end_idx -= 1
      next
    end

    if same?(old_start_vnode, new_end_vnode)
      patch_vnode(old_start_vnode, new_end_vnode)
      move(old_start_vnode, after: old_end_vnode)
      old_start_idx += 1
      new_end_idx -= 1
      next
    end

    if same?(old_end_vnode, new_start_vnode)
      patch_vnode(old_end_vnode, new_start_vnode)
      move(old_end_vnode, before: old_start_vnode)
      old_end_idx -= 1
      new_start_idx += 1
      next
    end

    old_key_to_idx = create_key_to_old_idx(old_ch, old_start_idx, old_end_idx)

    idx_in_old = new_start_vnode[:key] && old_key_to_idx[new_start_vnode[:key]]

    unless idx_in_old
      insert(init_vnode(new_start_vnode), before: old_start_vnode)
      new_start_idx += 1
      next
    end

    vnode_to_move = old_ch[idx_in_old]

    if same?(vnode_to_move, new_start_vnode)
      old_ch[idx_in_old] = nil
      move(patch_vnode(vnode_to_move, new_start_vnode), before: old_start_vnode)
      new_start_idx += 1
      next
    end

    puts "Same key but different element, treat as new element"
    insert(init_vnode(new_start_vnode), before: old_start_vnode)

    new_start_idx += 1
  end

  if old_start_idx > old_end_idx
    # TODO: something about ref elms from the new children
    new_ch
      .slice(new_start_idx..new_end_idx)
      .each { |vnode| insert(init_vnode(descriptor), before: nil) }
  elsif new_start_idx > new_end_idx
    old_ch
      .slice(old_start_idx..old_end_idx)
      .each { |vnode| remove_vnode(vnode) }
  end
end

def create_key_to_old_idx(children, start_idx, end_idx)
  start_idx.upto(end_idx).reduce({}) { |h, i| h.merge[children[i].key] = i }
end

def same?(a, b)
  a[:key] == b[:key]
end

def patch_vnode(a, b)
  puts "Patching #{a} with #{b}"
  a.merge(b)
end

def remove_vnode(vnode)
  puts "Removing #{vnode.inspect}"
end

def move(vnode, before: nil, after: nil)
  if before
    puts "move #{vnode.inspect} before #{before}"
  elsif after
    puts "move #{vnode.inspect} after #{after}"
  else
    puts "move #{vnode.inspect} last"
  end
end

old_ch = [
  { key: 1, name: "one" },
  { key: 2, name: "two" },
  { key: 3, name: "three" },
  { key: nil, name: "four" },
  { key: nil, name: "five" }
]

new_ch = [
  { key: 2, name: "two" },
  { key: 3, name: "three" },
  { key: nil, name: "four" },
  { key: 1, name: "one" }
]

update_children(old_ch, new_ch)
