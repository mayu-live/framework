module Diff3
  class VNode
    attr_reader :id
    attr_accessor :descriptor
    attr_accessor :children

    def initialize(id, descriptor)
      @id = id
      @descriptor = descriptor
      @children = []
    end

    def inspect
      "<#VNode:#{id} type=#{descriptor} key=#{descriptor}>"
    end
  end

  class Descriptor
    attr_reader :key
    attr_reader :type
    attr_reader :props

    def initialize(type, props = {}, children = [])
      @type = type
      @props = props.merge(children:)
      @key = @props.delete(:key)
    end

    def same?(other)
      type == other.type && key == other.key
    end
  end

  @last_id = 0

  def self.init_vnode(descriptor)
    VNode.new(@last_id += 1, descriptor)
  end

  def self.diff(old_ch, new_ch, &compare)
    old_start_idx = 0
    new_start_idx = 0
    old_end_idx = old_ch.length.pred
    new_end_idx = new_ch.length.pred

    instructions = []

    while old_start_idx <= old_end_idx && new_start_idx <= new_end_idx
      old_start_idx += 1 and next unless old_start_vnode = old_ch[old_start_idx]
      old_end_idx -= 1  and next unless old_end_vnode = old_ch[old_end_idx]
      new_start_vnode = new_ch[new_start_idx]
      new_end_vnode = new_ch[new_end_idx]

      if compare.call(old_start_vnode, new_start_vnode)
        instructions.push([:patch, old_start_vnode.id, new_start_vnode])
        old_start_idx += 1
        new_start_idx += 1
        next
      end

      if compare.call(old_end_vnode, new_end_vnode)
        instructions.push([:patch, old_end_vnode.id, new_end_vnode])
        old_end_idx -= 1
        new_end_idx -= 1
        next
      end

      if compare.call(old_start_vnode, new_end_vnode)
        instructions.push([:patch, old_start_vnode.id, new_end_vnode])
        instructions.push([:move, old_start_vnode.id, after: old_end_vnode.id])
        old_start_idx += 1
        new_end_idx -= 1
        next
      end

      if compare.call(old_end_vnode, new_start_vnode)
        instructions.push([:patch, old_end_vnode.id, new_start_vnode])
        instructions.push([:move, old_end_vnode.id, before: old_start_vnode.id])
        old_end_idx -= 1
        new_start_idx += 1
        next
      end

      old_key_to_idx = build_key_index_map(old_ch, old_start_idx, old_end_idx)

      idx_in_old = new_start_vnode.key && old_key_to_idx[new_start_vnode.key]
      vnode_to_move = idx_in_old && old_ch[idx_in_old]

      unless vnode_to_move
        instructions.push([:insert, new_end_vnode, before: old_start_vnode.id])
        new_start_idx += 1
        next
      end

      if compare.call(vnode_to_move, new_start_vnode)
        instructions.push([:patch, vnode_to_move.id, new_start_vnode])
        instructions.push([:move, vnode_to_move.id, before: old_start_vnode.id])
        new_start_idx += 1
        next
      end

      puts "Same key but different element, treat as new element"
      instructions.push([:insert, descriptor, before: old_start_vnode.id])

      new_start_idx += 1
    end

    if old_start_idx > old_end_idx
      # TODO: something about ref elms from the new children
      #  refElm = isUndef(newCh[newEndIdx + 1]) ? null : newCh[newEndIdx + 1].elm
      ref_elm = old_ch[old_end_idx.succ]
      descriptors_to_add = new_ch.slice(new_start_idx..new_end_idx)
      descriptors_to_add.each do |descriptor|
        instructions.push([:insert, descriptor, before: ref_elm&.id])
      end if descriptors_to_add
    elsif new_start_idx > new_end_idx
      vnodes_to_remove = old_ch.slice(old_start_idx..old_end_idx)
      vnodes_to_remove.each do |vnode|
        # unless moved_ids.include?(vnode.id)
          instructions.push([:remove, vnode.id])
        # end
      end if vnodes_to_remove
    end

    instructions
  end

  def self.build_key_index_map(children, start_index, end_index)
    keymap = {}

    start_index.upto(end_index) do |i|
      if key = children[i]&.descriptor&.key
        keymap[key] = i
      end
    end

    keymap
  end

  def self.patch(children, patches)
    patches.each { p _1 }
    patches.each do |patch|
      type, *rest = patch
      case patch
      in :insert, descriptor, { before: }
        index = children.map(&:id).index(before) || -1
        children.insert(index, init_vnode(descriptor))
      in :patch, id, descriptor
        child = children.find { |child| child.id == id }
        child.descriptor = descriptor
      in :remove, id
        children.delete_if { |child| child.id == id }
      else
        p patch
      end
    end

    children
  end
end

def self.h(type, *args, **props, &block)
  Diff3::Descriptor.new(type, props, args.concat([block&.call].flatten.compact))
end

children = []

children = Diff3.patch(children, Diff3.diff(children, [
  h(:p, "p"),
  h(:span, "span"),
  h(:div, "div"),
]) { |vnode, descriptor| vnode.descriptor.same?(descriptor) })

p children

children = Diff3.patch(children, Diff3.diff(children, [
  h(:p, "p"),
  h(:span, "span"),
]) { |vnode, descriptor| vnode.descriptor.same?(descriptor) })

p children

children = Diff3.patch(children, Diff3.diff(children, [
  h(:p, "p"),
  h(:xspan, "span"),
]) { |vnode, descriptor| vnode.descriptor.same?(descriptor) })

p children
