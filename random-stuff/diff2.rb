def same?(vnode, descriptor)
  vnode[:key] == descriptor[:key] && vnode[:type] == descriptor[:type]
end

@id = 0

def vnode_from_descriptor(desc)
  id = @id += 1
  { id:, **desc }
end

def patch(vnode, descriptor)
  vnode = vnode.merge(descriptor)
  p [:patch, vnode, descriptor]
  vnode
end

def insert(descriptor, before: nil)
  vnode = vnode_from_descriptor(descriptor)
  p [:insert, vnode, before:]
  vnode
end

def remove(vnode)
  p [:remove, vnode]
  vnode
end

def diff2(vnodes, descriptors)
  puts "Diffing"
  vnodes = vnodes.reverse
  descriptors = descriptors.reverse

  last = nil

  result = descriptors.map do |descriptor|
    index = vnodes.find_index { same?(_1, descriptor) }

    unless index
      vnode = insert(descriptor, before: last && last[:id])
      next last = vnode
    end

    vnode = vnodes.delete_at(index)
    last = patch(vnode, descriptor)
  end

  vnodes.each do |vnode|
    remove(vnode)
  end

  result.reverse
end

def v(type, content, key: nil)
  { type:, content:, key: }
end

children = []
children = diff2(children, [
  v(:p, 1, key: 1),
  v(:p, 2, key: 2),
  v(:p, 3, key: 3),
])
children = diff2(children, [
  v(:p, 1, key: 1),
  v(:p, 3, key: 3),
  v(:p, 2, key: 2),
  v(:p, 2, key: 5),
])
children = diff2(children, [
  v(:p, 1, key: 1),
  v(:p, 2, key: 5),
  v(:p, 2, key: 2),
])
