def same?(vnode1, vnode2)
  vnode1.key == vnode2.key
end

class RangeIterator
  def initialize(array)
    @array = array
    @start_idx = 0
    @end_idx = @array.length.pred
  end

  def done?
    @start_idx >= @end_idx
  end

  def start
    @array[@start_idx]
  end

  def end
    @array[@end_idx]
  end

  def move_start
    @start_idx += 1
  end

  def move_end
    @start_idx += 1
  end
end

def check_duplicate_keys(vnodes)
  keys = vnodes.map(&:key).compact
  duplicates = keys.reject { keys.rindex(_1) == keys.index(_1) }
  duplicates.each do |key|
    "Duplicate keys detected: '#{key}'. This may cause an update error."
  end
end

def diff_list(list1, list2)
  left = RangeIterator.new(list1)
  right = RangeIterator.new(list2)

  moved_indexes = []

  check_duplicate_keys(list2)

  keymap = nil

  until left.done? || right.done?
    left.next_start! and next unless left.start
    left.next_end! and next unless left.end
    right.next_start! and next unless right.start
    right.next_end! and next unless right.end

    if same?(left.start, right.start)
      puts "Keep #{left.start} at #{right.start_idx}"
      left.next_start!
      right.next_start!
      next
    end

    if same?(left.end, right.end)
      puts "Keep #{left.end} at #{right.end_idx}"
      left.next_end!
      right.next_end!
      next
    end

    if same?(left.start, right.end)
      puts "Move #{left.start} to #{right.end_idx}"
      left.next_start!
      right.next_end!
      next
    end

    if same?(left.end, right.start)
      puts "Move #{left.end} to #{right.start_idx}"
      left.next_end!
      right.next_start!
      next
    end

    keymap = build_key_index_map(list1, left.start_idx, left.end_idx)

    if index = keymap[right.start.key]
      vnode_to_move = list1[index]
      moved_indexes.push(index)

      puts "Move #{vnode_to_move} to #{right.start_idx}"

      right.next_start!
      next
    end

    puts "Insert #{right.start} at #{right.start_idx}"

    right.next_start!
  end

  if left.done?
    ref_elm = list2[right.end_idx + 1]&.key

    right.start_idx.upto(right.end_idx).each do |i|
      if ref_elm
        puts "Insert #{list2[i]} before #{ref_elm.inspect}"
      else
        puts "Append #{list2[i]}"
      end
    end
  elsif right.done?
    left.start_idx.upto(left.end_idx).each do |i|
      next if moved_indexes.include?(i)
      vnode = list1[i]
      puts "Remove #{list1[i]}"
    end
  end
end

def build_key_index_map(children, start_index, end_index)
  keymap = {}

  start_index.upto(end_index) do |i|
    key = children[i]&.key
    keymap[key] = i if key
  end

  keymap
end

class Descriptor
  TEXT = :TEXT
  COMMENT = :COMMENT

  attr_reader :key
  attr_reader :type
  attr_reader :props

  def initialize(type, props = {}, children = [])
  end

  def same?(other)
    if key == other.key && type == other.type
      if type == :input
        props[:type] == props[:type]
      else
        true
      end
    else
      false
    end
  end
end

class VNode
  attr_reader :key
  attr_reader :content

  def initialize(content, key: nil)
    @key = key
    @content = content
  end

  def to_s
    "<VNode key={#{key.inspect}} content=#{@content.inspect}>"
  end
end

list1 = [
  VNode.new('keyed1', key: 'keyed1'),
  VNode.new('keyed2', key: 'keyed2'),
  VNode.new('keyed3', key: 'keyed3'),
  VNode.new('unkeyed1'),
]

list2 = [
  VNode.new('keyed2', key: 'keyed2'),
  VNode.new('unkeyed1'),
  VNode.new('keyed3', key: 'keyed3'),
]

diff_list(list1, list2)
