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

  def new_component
    if @type.is_a?(Class) && @type < Component
      @type.new(**props)
    end
  end

  def text? = @type == TEXT
  def comment? = @type == COMMENT
  def element? = @type.is_a?(Symbol) && !text? && !comment?
  def children = props[:children]
  def children? = children.any?

  def text
    content = props[:text_content].to_s
    if content.empty?
      "&ZeroWidthSpace;"
    else
      CGI.escape_html(content)
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

	def id = object_id

  def initialize(vdom, descriptor)
		@vdom = vdom
    @descriptor = descriptor
    @component = nil
    @children = []
  end

  def new_component
    @component ||= @descriptor.new_component
  end

  def mount
    @component&.mount
  end

  def unmount
    @component&.unmount
  end

  def to_s
    return children.join if component
    return "<!--mayu-id-#{id}-->" if descriptor.comment?
    return descriptor.text if descriptor.text?

    type = descriptor.type
    attrs = descriptor.props
			.except(:children)
			.merge(data_mayu_id: id)
      .map { %{ #{_1.to_s.sub(/^on_/, "on").tr("_", "-")}="#{_2}"} }
			.join

    if type.is_a?(Symbol) && VOID_TAGS.include?(type.to_s)
      format("<%<type>s%<attrs>s>", type:, attrs:)
    else
			children = @children.join
      format("<%<type>s%<attrs>s>%<children>s</%<type>s>", type:, attrs:, children:)
    end
  end

	def id_tree
		if component
      children.first&.id_tree
		elsif children.empty?
			id
		else
      [id, children.map(&:id_tree).compact]
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

class VDOM
	class UpdateContext
    attr_reader :patches

		def initialize
      @patches = []
      @parents = []
      @dom_parents = []
		end

    def parent
      @parents.last
    end

    def dom_parent
      @dom_parents.last
    end

    def enter(vnode)
      @parents.push(vnode)
      @dom_parents.push(vnode) if vnode.descriptor.element?
      yield
      @dom_parents.pop if vnode.descriptor.element?
      @parents.pop
    end

    def insert(vnode, before: nil, after: nil)
      html = vnode.to_s
      ids = vnode.id_tree

      if before
        add_patch(:insert, id: vnode.id, parent: dom_parent&.id, before: before.id, html:, ids:)
      elsif after
        add_patch(:insert, id: vnode.id, parent: dom_parent&.id, after: after.id, html:, ids:)
      else
        add_patch(:insert, id: vnode.id, parent: dom_parent&.id, html:, ids:)
      end
    end

    def move(vnode, before: nil, after: nil)
      if before
        add_patch(:move, id: vnode.id, parent: dom_parent&.id, before: before.id)
      elsif after
        add_patch(:move, id: vnode.id, parent: dom_parent&.id, after: after.id)
      else
        add_patch(:move, id: vnode.id, parent: dom_parent&.id)
      end
    end

    def remove(vnode)
      add_patch(:remove, id: vnode.id, parent: dom_parent&.id)
    end

    private

    def add_patch(type, **args)
      @patches.push([type, args])
    end
	end

	def initialize
		@root = nil
	end

	def render(descriptor)
    ctx = UpdateContext.new
		@root = patch(ctx, @root, descriptor)
    p ctx.patches
    @root
	end

	private

	def patch(ctx, vnode, descriptor)
		unless vnode
			vnode = init_vnode(ctx, descriptor)
      ctx.insert(vnode)
      return vnode
		end

		unless descriptor
			return remove_vnode(ctx, vnode)
		end

		if vnode.descriptor.same?(descriptor)
			patch_vnode(ctx, vnode, descriptor)
		else
			remove_vnode(ctx, vnode)
			vnode = init_vnode(ctx, descriptor)
      ctx.insert(vnode)
      return vnode
		end
	end

	def patch_vnode(ctx, vnode, descriptor)
		unless vnode.descriptor.same?(descriptor)
			raise "Can not patch different types!"
		end

		component = vnode.component
		new_children = descriptor.children

		if component
			if component.should_update?(descriptor.props, component.next_state) # TODO: || component.dirty?
				component.props = descriptor.props
				component.state = component.next_state.clone

        ctx.enter(vnode) do
          vnode.children = update_children(ctx, vnode.children.compact, Array(component.render).compact)
        end

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
          ctx.enter(vnode) do
            vnode.children = update_children(ctx, vnode.children, new_children)
          end
				end
			elsif descriptor.children?
				check_duplicate_keys(descriptor.children)
				puts "adding new children"

        ctx.enter(vnode) do
          vnode.children = descriptor.children.map { init_vnode(ctx, _1) }
        end
			elsif vnode.descriptor.children?
        ctx.enter(vnode) do
          vnode.descriptor.children.each { remove_vnode(ctx, _1) }
        end
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

	def remove_vnodes(ctx, vnodes)
		vnodes.each do |vnode|
			remove_vnode(ctx, vnode)
		end
	end

	def set_text_content(vnode, content)
		puts "update_text(#{vnode.id}, #{content.inspect})"
	end

	def init_vnode(ctx, descriptor, nested: false)
		vnode = VNode.new(self, descriptor)
		component = vnode.new_component

		children = descriptor.children

      children =
        if component
          Array(component.render).compact
        else
          descriptor.children
        end

    ctx.enter(vnode) do
      vnode.children = children.map { init_vnode(ctx, _1, nested: true) }
    end

		vnode.component&.mount

		vnode
	end

	def remove_vnode(ctx, vnode, patch: true)
    ctx.remove(vnode) if patch
		vnode.children.map { remove_vnode(ctx, _1, patch: false) }
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

	def update_children(ctx, vnodes, descriptors)
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
				children[descriptors.start_idx] = patch_vnode(ctx, vnodes.start, descriptors.start)
				vnodes.next_start
				descriptors.next_start
				next
			end

			if vnodes.end.descriptor.same?(descriptors.end)
				children[descriptors.end_idx] = patch_vnode(ctx, vnodes.end, descriptors.end)
				vnodes.next_end
				descriptors.next_end
				next
			end

			if vnodes.start.descriptor.same?(descriptors.end)
				children[descriptors.end_idx] = patch_vnode(ctx, vnodes.start, descriptors.end)
				ctx.move(vnodes.start, after: vnodes.end)
				vnodes.next_start
				descriptors.next_end
				next
			end

			if vnodes.end.descriptor.same?(descriptors.start)
				children[descriptors.start_idx] = patch_vnode(ctx, vnodes.end, descriptors.start)
				ctx.move(vnodes.end, before: vnodes.start)
				vnodes.next_end
				descriptors.next_start
				next
			end

			keymap = build_key_index_map(vnodes, vnodes.start_idx, vnodes.end_idx)

			if index = keymap[descriptors.start.key]
				vnode_to_move = vnodes[index]
				moved_indexes.push(index)

				children[descriptors.start_idx] = patch_vnode(ctx, vnode_to_move, descriptors.start)
				ctx.move(vnode_to_move, before: vnodes.start)

				descriptors.next_start
				next
			end

			p "same key but different element. treat as new element"
      p descriptors.start
      p descriptors.end
      p vnodes.start.descriptor
      p vnodes.end.descriptor
			vnode = init_vnode(ctx, descriptors.start)
			children[descriptors.start_idx] = vnode
			ctx.insert(vnode, before: vnodes.start)

			descriptors.next_start
		end

		if vnodes.start_idx > vnodes.end_idx
			ref_elm = descriptors[descriptors.end_idx + 1]

			descriptors.start_idx.upto(descriptors.end_idx).each do |i|
				vnode = init_vnode(ctx, descriptors[i])

				ctx.insert(vnode, before: ref_elm)
			end
		elsif descriptors.start_idx > descriptors.end_idx
			vnodes.start_idx.upto(vnodes.end_idx).each do |i|
				next if moved_indexes.include?(i)
				vnode = vnodes[i]
				ctx.remove(vnodes[i])
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

def component(&block)
  Class.new(Component) do
    define_method(:render) do
      props = self.props

      Markup.build do
        instance_exec(**props, &block)
      end
    end
  end
end

App = component do
  div do
    span "hello world", class: "hej"

    ul do
      10.times do |i|
        li "hello #{i}", key: i
      end
    end
  end
end

App2 = component do
  div do
    span "hello world", class: "hej"

    ul do
      10.times do |i|
        li "hello #{i}", key: i
      end
    end
  end
end

vdom = VDOM.new
tree = vdom.render(Descriptor.new(App))
puts tree
tree = vdom.render(Descriptor.new(App2))
puts tree

# d1 = Descriptor.new(:TEXT, { text_content: "hello" })
# d2 = Descriptor.new(:TEXT, { text_content: "foobar" })
# vnode = init_vnode(ctx, d1)
# puts vnode
# vnode = patch_vnode(ctx, vnode, d2)
# puts vnode
