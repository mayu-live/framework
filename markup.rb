require "json"
require "cgi"

TAGS = JSON.parse(File.read("html-tags.json"))
VOID_TAGS = JSON.parse(File.read("html-tags-void.json"))

class Descriptor
  TEXT = :TEXT
  COMMENT = :COMMENT

  attr_reader :key
  attr_reader :type
  attr_reader :props

  def text
    content = props[:text_content].to_s
    if content.empty?
      "&ZeroWidthSpace;"
    else
      CGI.escape_html(content)
    end
  end

  def text? = @type == TEXT
  def children = props[:children]
  def children? = children.any?

  def initialize(type, props = {}, children = [])
    @type = type
    @props = props.merge(
      children: children.map do |child|
        if child.is_a?(self.class)
          child
        else
					raise child unless child.is_a?(String)
          Descriptor.new(TEXT, { text_content: child })
        end
      end
    )
    @key = props.delete(:key)
  end

  def init_component
    if @type.is_a?(Class) && @type < Component
      @type.new(**props)
    end
  end

  def to_s
    return text if text?

    type = @type
    attrs = @props.except(:children).map { %{ #{_1}="#{_2}"} }.join

    if type.is_a?(Symbol) && VOID_TAGS.include?(type.to_s)
      format("<%<type>s%<attrs>s>", type:, attrs:)
    else
      children = @props[:children].join
      format("<%<type>s%<attrs>s>%<children>s</%<type>s>", type:, attrs:, children:)
    end
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

class Component
  attr_accessor :props
  attr_accessor :state
  attr_accessor :next_state

  def initialize(**props)
    @props = props
    @state = {}
    @next_state = {}
  end

  def should_update?(next_props, next_state)
    !(props == next_props && state == next_state)
  end

  def mount = nil
  def unmount = nil
  def did_update = nil
  def render = nil
end

class VNode
  attr_accessor :descriptor
  attr_accessor :component
  attr_accessor :children

  def initialize(descriptor)
    @descriptor = descriptor
    @component = nil
    @children = []
  end

  def init_component
    @component ||= @descriptor.init_component
  end

  def mount
    @component&.mount
  end

  def unmount
    @component&.unmount
  end

  def to_s
    return descriptor.text if descriptor.text?

    type = descriptor.type
    attrs = descriptor.props.except(:children).map { %{ #{_1}="#{_2}"} }.join

    if type.is_a?(Symbol) && VOID_TAGS.include?(type.to_s)
      format("<%<type>s%<attrs>s>", type:, attrs:)
    else
			children = @children.join
      format("<%<type>s%<attrs>s>%<children>s</%<type>s>", type:, attrs:, children:)
    end
  end
end

class AsyncComponent < Component
  def initialize(props)
    super
    @block = props[block]
  end

  def to_s
    "async"
  end
end

class Markup
  def self.build(&block)
    new.capture(&block).first
  end

  def initialize
    @streams = []
  end

  def capture(&block)
    @streams.push([])
    instance_eval(&block)
    @streams.pop
  end

  def async(&block)
    @streams.last << Descriptor.new(
      AsyncComponent.new(block: block),
    )
  end

  def method_missing(sym, *args, **props, &block)
    super unless TAGS.include?(sym.to_s)

    h(sym, *args, **props, &block)
  end

  def str(content)
    @streams.last << Descriptor.new(
      Descriptor::TEXT,
      { text_content: content }
    )
  end

  def h(type, *args, **props, &block)
    @streams.last << Descriptor.new(
      type,
      props,
      args.concat(block ? capture(&block) : []),
    )
  end
end

def patch(vnode, descriptor)
  unless vnode
    return init_vnode(descriptor)
  end

  unless descriptor
    return remove_vnode(vnode)
  end

  if vnode.descriptor.same?(descriptor)
    patch_vnode(vnode, descriptor)
  else
    remove_vnode(vnode)
    init_vnode(descriptor)
  end
end

def patch_vnode(vnode, descriptor)
  unless vnode.descriptor.same?(descriptor)
    raise "Can not patch different types!"
  end

  component = vnode.component
  new_children = descriptor.children

  if component
    if component.should_update?(descriptor.props, component.next_state) # TODO: || component.dirty?
      component.props = descriptor.props
      component.state = component.next_state.clone
      vnode.children = update_children(vnode.children.compact, Array(component.render).compact)
      vnode.descriptor = descriptor
      return vnode
    else
      return vnode
    end
  elsif vnode.descriptor == descriptor
    puts "returning early"
    return vnode
  end

  if descriptor.text?
    unless vnode.descriptor.text == descriptor.text
      set_text_content(vnode, descriptor.text)
    end
  else
    if vnode.descriptor.children? && descriptor.children?
      if vnode.descriptor.children != descriptor.children
        vnode.children = update_children(vnode.children, new_children)
      end
    elsif descriptor.children?
      check_duplicate_keys(descriptor.children)
			puts "adding new children"

      vnode.children = descriptor.children.map { init_vnode(_1) }
    elsif vnode.descriptor.children?
      vnode.descriptor.children.each { remove_vnode(_1) }
			vnode.children = []
    elsif vnode.descriptor.text?
      set_text_content(vnode, "")
		else
			puts "got here"
    end
  end

  vnode.descriptor = descriptor

  component&.did_update

  vnode
end

def remove_vnodes(vnodes)
  vnodes.each do |vnode|
    puts "Removing vnode #{vnode}"
  end
end

def set_text_content(vnode, content)
  puts "update_text(#{vnode.object_id}, #{content.inspect})"
end

def init_vnode(descriptor)
  vnode = VNode.new(descriptor)
  component = vnode.init_component

  children = descriptor.children

  children =
    if component
      Array(component.render).compact
    else
      descriptor.children
    end

  vnode.children = children.map { init_vnode(_1) }

  vnode
end

def remove_vnode(vnode)
  puts "Removing #{vnode.descriptor.type}"
  vnode.children.map { _1.unmount }
  vnode.unmount
  nil
end

class RangeIterator
  include Enumerable

  attr_reader :start_idx
  attr_reader :end_idx

  def initialize(array)
    @array = array
    @start_idx = 0
    @end_idx = @array.length
  end

  def [](index)
    @array[index]
  end

  def each(&block)
    @start_idx.upto(@end_idx) do |i|
      yield @array[i] if @array[i]
    end
  end

  def length = @end_idx - @start_idx
  def done? = @start_idx > @end_idx
  def start = @array[@start_idx]
  def end = @array[@end_idx]
  def next_start = @start_idx += 1
  def next_end = @end_idx -= 1
end

def check_duplicate_keys(descriptors)
  keys = descriptors.map(&:key).compact
  duplicates = keys.reject { keys.rindex(_1) == keys.index(_1) }
  duplicates.each do |key|
    "Duplicate keys detected: '#{key}'. This may cause an update error."
  end
end

def update_children(vnodes, descriptors)
	initial_descriptors_length = descriptors.compact.length
  vnodes = RangeIterator.new(vnodes)
  descriptors = RangeIterator.new(descriptors)
  children = Array.new(descriptors.length)

  moved_indexes = []

  check_duplicate_keys(descriptors)

  keymap = nil

  until vnodes.done? || descriptors.done?
    # p [vnodes.start_idx, vnodes.end_idx]
    # p [descriptors.start_idx, descriptors.end_idx]
    vnodes.next_start and next unless vnodes.start
    vnodes.next_end and next unless vnodes.end
    descriptors.next_start and next unless descriptors.start
    descriptors.next_end and next unless descriptors.end

    if vnodes.start.descriptor.same?(descriptors.start)
      puts "Keep #{vnodes.start} at #{descriptors.start_idx}"
      children[descriptors.start_idx] = patch_vnode(vnodes.start, descriptors.start)
      vnodes.next_start
      descriptors.next_start
      next
    end

    if vnodes.end.descriptor.same?(descriptors.end)
      puts "Keep #{vnodes.end} at #{descriptors.end_idx}"
      children[descriptors.end_idx] = patch_vnode(vnodes.end, descriptors.end)
      vnodes.next_end
      descriptors.next_end
      next
    end

    if vnodes.start.descriptor.same?(descriptors.end)
      puts "Move #{vnodes.start} to #{descriptors.end_idx}"
      children[descriptors.end_idx] = patch_vnode(vnodes.start, descriptors.end)
      vnodes.next_start
      descriptors.next_end
      next
    end

    if vnodes.end.descriptor.same?(descriptors.start)
      puts "Move #{vnodes.end} to #{descriptors.start_idx}"
      children[descriptors.start_idx] = patch_vnode(vnodes.end, descriptors.start)
      vnodes.next_end
      descriptors.next_start
      next
    end

    keymap = build_key_index_map(vnodes, vnodes.start_idx, vnodes.end_idx)

    if index = keymap[descriptors.start.key]
      vnode_to_move = vnodes[index]
      moved_indexes.push(index)

      puts "Move #{vnode_to_move} to #{descriptors.start_idx}"
      children[descriptors.start_idx] = patch_vnode(vnode_to_move, descriptors.start)

      descriptors.next_start
      next
    end

    puts "Insert #{descriptors.start} at #{descriptors.start_idx}"
    children[descriptors.start_idx] = init_vnode(descriptors.start)

    descriptors.next_start
  end

  if vnodes.start_idx > vnodes.end_idx
    ref_elm = descriptors[descriptors.end_idx + 1]&.key

    descriptors.start_idx.upto(descriptors.end_idx.pred).each do |i|
      vnode = init_vnode(descriptors[i])

      if ref_elm
        children[descriptors.length + 1 + i] = vnode
        puts "Insert #{descriptors[i]} before #{ref_elm.inspect}"
      else
        children[i] = vnode
        puts "Append #{descriptors[i]}"
      end
    end
  elsif descriptors.start_idx > descriptors.end_idx
    vnodes.start_idx.upto(vnodes.end_idx).each do |i|
      next if moved_indexes.include?(i)
      vnode = vnodes[i]
      puts "Remove #{vnodes[i]}"
    end
  else
    puts "Nothing to either add or remove"
  end

  children.compact
end

def build_key_index_map(children, start_index, end_index)
  keymap = {}

  start_index.upto(end_index) do |i|
    key = children[i].descriptor&.key
    keymap[key] = i if key
  end

  keymap
end

class AppComponent < Component
  def initialize(**props)
    p props
    super
  end

  def should_update?(next_props, next_state)
    p [next_props, next_state]
		true
  end

  def render
    puts "render"

    Markup.build do
      div do
        span "hello world", class: "hej"

				ul do
					10.times.to_a.shuffle.first(7).each do |i|
						li "hello #{i + rand(2)}", key: i
					end
				end
      end
    end
  end
end

app = Descriptor.new(AppComponent)

tree = patch(nil, app)
puts "patching"
tree = patch(tree, app)
puts "patching"
tree = patch(tree, app)
puts tree

# d1 = Descriptor.new(:TEXT, { text_content: "hello" })
# d2 = Descriptor.new(:TEXT, { text_content: "foobar" })
# vnode = init_vnode(d1)
# puts vnode
# vnode = patch_vnode(vnode, d2)
# puts vnode
