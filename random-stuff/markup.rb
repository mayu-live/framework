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
    @props =
      props.merge(
        children:
          children.map do |child|
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

  def new_component(vnode)
    @type.new(vnode, **props) if @type.is_a?(Class) && @type < Component
  end

  def self.comment = new(COMMENT)

  def text = props[:text_content].to_s
  def text? = @type == TEXT
  def comment? = @type == COMMENT
  def element? = @type.is_a?(Symbol) && !text? && !comment?
  def children = props[:children]
  def children? = children.any?

  def to_s
    return text if text?

    type = @type
    attrs = @props.except(:children).map { %{ #{_1}="#{_2}"} }.join

    if type.is_a?(Symbol) && VOID_TAGS.include?(type.to_s)
      format("<%<type>s%<attrs>s>", type:, attrs:)
    else
      children = @props[:children].join
      format(
        "<%<type>s%<attrs>s>%<children>s</%<type>s>",
        type:,
        attrs:,
        children:
      )
    end
  end

  def same?(other)
    if key == other.key && type == other.type
      type == :input ? props[:type] == props[:type] : true
    else
      false
    end
  end
end

class Component
  attr_accessor :props
  attr_accessor :state
  attr_accessor :next_state

  def initialize(vnode, **props)
    @vnode = vnode
    @props = props
    @state = {}
    @next_state = {}
  end

  def should_update?(next_props, next_state)
    !(props == next_props && state == next_state)
  end

  def enqueue_update!
    @__vnode.enqueue_update!
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

  def init_component
    @component ||= @descriptor.new_component(self)
  end

  def mount
    @component&.mount
  end

  def unmount
    @component&.unmount
  end

  def to_json
    return children.first&.to_json if component

    json = { id: id, type: descriptor.type.to_s }

    return "<--mayu-id=#{id}-->" if descriptor.comment?
    return descriptor.text if descriptor.text?

    props = descriptor.props.except(:children) if descriptor
    json.merge!(props: props) unless props.empty?
    json.merge!(children: children.map(&:to_json)) unless children.empty?
    json
  end

  def to_s
    return children.join if component
    return "<!--mayu-id-#{id}-->" if descriptor.comment?

    if descriptor.text?
      content = descriptor.text

      if content.empty?
        return "&ZeroWidthSpace;"
      else
        return CGI.escape_html(content)
      end
    end

    type = descriptor.type
    attrs =
      descriptor
        .props
        .except(:children)
        .merge(data_mayu_id: id)
        .map { %{ #{_1.to_s.sub(/^on_/, "on").tr("_", "-")}="#{_2}"} }
        .join

    if type.is_a?(Symbol) && VOID_TAGS.include?(type.to_s)
      format("<%<type>s%<attrs>s>", type:, attrs:)
    else
      children = @children.join
      format(
        "<%<type>s%<attrs>s>%<children>s</%<type>s>",
        type:,
        attrs:,
        children:
      )
    end
  end

  def id_tree
    if component
      children.first&.id_tree
    else
      ch = children.map(&:id_tree).compact
      ch.empty? ? { id: } : { id:, ch: }
    end
  end
end

class AsyncComponent < Component
  def mount
    @task = Async(&params[:block])
  end

  def unmount
    @task.stop
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
    @streams.last << Descriptor.new(AsyncComponent.new(block: block))
  end

  def method_missing(sym, *args, **props, &block)
    const =
      begin
        ::Kernel.const_get(sym)
      rescue StandardError
        nil
      end

    if const.is_a?(Class) && const < Component
      return h(const, *args, **props, &block)
    end

    super unless TAGS.include?(sym.to_s)

    h(sym, *args, **props, &block)
  end

  def str(content)
    @streams.last << Descriptor.new(Descriptor::TEXT, { text_content: content })
  end

  def h(type, *args, **props, &block)
    @streams.last << Descriptor.new(
      type,
      props,
      args.concat(block ? capture(&block) : [])
    )
  end
end

class VDOM
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
      @start_idx.upto(@end_idx) { |i| yield @array[i] if @array[i] }
    end

    def length = @end_idx - @start_idx
    def done? = @start_idx > @end_idx
    def start = @array[@start_idx]
    def end = @array[@end_idx]
    def next_start = @start_idx += 1
    def next_end = @end_idx -= 1
  end

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

    def insert(vnode, before: nil, after: nil, &block)
      p caller.first(5)
      html = vnode.to_s
      ids = vnode.id_tree

      if before
        add_patch(
          :insert,
          id: vnode.id,
          parent: dom_parent&.id,
          before: before.id,
          html:,
          ids:
        )
      elsif after
        add_patch(
          :insert,
          id: vnode.id,
          parent: dom_parent&.id,
          after: after.id,
          html:,
          ids:
        )
      else
        add_patch(:insert, id: vnode.id, parent: dom_parent&.id, html:, ids:)
      end
    end

    def move(vnode, before: nil, after: nil)
      if before
        add_patch(
          :move,
          id: vnode.id,
          parent: dom_parent&.id,
          before: before.id
        )
      elsif after
        add_patch(:move, id: vnode.id, parent: dom_parent&.id, after: after.id)
      else
        add_patch(:move, id: vnode.id, parent: dom_parent&.id)
      end
    end

    def text(vnode, text)
      add_patch(:text, id: vnode.id, text:)
    end

    def remove(vnode)
      add_patch(:remove, id: vnode.id, parent: dom_parent&.id)
    end

    private

    def add_patch(type, **args)
      puts "\e[33m#{type}:\e[0m #{args.inspect}"
      @patches.push(args.merge(type:))
    end
  end

  def initialize
    @root = nil
  end

  def render(descriptor)
    ctx = UpdateContext.new
    @root = patch(ctx, @root, descriptor)
    yield ctx.patches if block_given?
    @root
  end

  private

  def patch(ctx, vnode, descriptor)
    unless vnode
      vnode = init_vnode(ctx, descriptor)
      ctx.insert(vnode)
      return vnode
    end

    return remove_vnode(ctx, vnode) unless descriptor

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
      if component.should_update?(descriptor.props, component.next_state)
        vnode.descriptor = descriptor
        component.props = descriptor.props
        component.state = component.next_state.clone
        descriptors =
          add_comments_between_texts(Array(component.render).compact)

        ctx.enter(vnode) do
          vnode.children =
            update_children(ctx, vnode.children.compact, descriptors)
        end
      end

      return vnode
    end

    return vnode if vnode.descriptor == descriptor

    if descriptor.text?
      unless vnode.descriptor.text == descriptor.text
        vnode.descriptor = descriptor
        ctx.text(vnode, descriptor.text)
        return vnode
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
          vnode.children =
            add_comments_between_texts(descriptor.children).map do
              init_vnode(ctx, _1).tap { |child| ctx.insert(child) }
            end
        end
      elsif vnode.children.length > 0
        ctx.enter(vnode) { vnode.children.each { remove_vnode(ctx, _1) } }
        vnode.children = []
      elsif vnode.descriptor.text?
        ctx.patch(:text, vnode, "")
      else
        puts "got here"
      end
    end

    vnode.descriptor = descriptor

    component&.did_update

    vnode
  end

  def remove_vnodes(ctx, vnodes)
    vnodes.each { |vnode| remove_vnode(ctx, vnode) }
  end

  def set_text_content(ctx, vnode, content)
    ctx.text(vnode.id, content.to_s)
  end

  def render_component(vnode)
  end

  def init_vnode(ctx, descriptor, nested: false)
    vnode = VNode.new(self, descriptor)
    component = vnode.init_component

    children = descriptor.children

    children =
      (component ? Array(component.render).compact : descriptor.children)

    ctx.enter(vnode) do
      vnode.children =
        add_comments_between_texts(children).map do
          init_vnode(ctx, _1, nested: true)
        end
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

  def check_duplicate_keys(descriptors)
    keys = descriptors.map(&:key).compact
    duplicates = keys.reject { keys.rindex(_1) == keys.index(_1) }.uniq
    duplicates.each do |key|
      puts "\e[31mDuplicate keys detected: '#{key}'. This may cause an update error.\e[0m"
    end
  end

  def update_children(ctx, vnodes, descriptors)
    # descriptors = add_comments_between_texts(descriptors)
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
        children[descriptors.start_idx] = patch_vnode(
          ctx,
          vnodes.start,
          descriptors.start
        )
        vnodes.next_start
        descriptors.next_start
        next
      end

      if vnodes.end.descriptor.same?(descriptors.end)
        children[descriptors.end_idx] = patch_vnode(
          ctx,
          vnodes.end,
          descriptors.end
        )
        vnodes.next_end
        descriptors.next_end
        next
      end

      if vnodes.start.descriptor.same?(descriptors.end)
        children[descriptors.end_idx] = patch_vnode(
          ctx,
          vnodes.start,
          descriptors.end
        )
        ctx.move(vnodes.start, after: vnodes.end)
        vnodes.next_start
        descriptors.next_end
        next
      end

      if vnodes.end.descriptor.same?(descriptors.start)
        children[descriptors.start_idx] = patch_vnode(
          ctx,
          vnodes.end,
          descriptors.start
        )
        ctx.move(vnodes.end, before: vnodes.start)
        vnodes.next_end
        descriptors.next_start
        next
      end

      keymap = build_key_index_map(vnodes, vnodes.start_idx, vnodes.end_idx)

      if index = keymap[descriptors.start.key]
        vnode_to_move = vnodes[index]
        moved_indexes.push(index)

        children[descriptors.start_idx] = patch_vnode(
          ctx,
          vnode_to_move,
          descriptors.start
        )
        ctx.move(vnode_to_move, before: vnodes.start)

        descriptors.next_start
        next
      end

      # We found a new child

      vnode = init_vnode(ctx, descriptors.start)
      children[descriptors.start_idx] = vnode
      ctx.insert(vnode, before: vnodes.start)

      descriptors.next_start
    end

    if vnodes.start_idx > vnodes.end_idx
      ref_elm = descriptors[descriptors.end_idx + 1]

      descriptors
        .start_idx
        .upto(descriptors.end_idx)
        .each do |i|
          vnode = init_vnode(ctx, descriptors[i])
          children.push(vnode)

          ctx.insert(vnode) # before: ref_elm)
        end
    elsif descriptors.start_idx > descriptors.end_idx
      vnodes
        .start_idx
        .upto(vnodes.end_idx)
        .each do |i|
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
      if key = children[i].descriptor&.key
        keymap[key] = i
      end
    end

    keymap
  end

  def add_comments_between_texts(descriptors)
    comment = Descriptor.comment
    prev = nil

    descriptors
      .map
      .with_index do |curr, i|
        prev2 = prev
        prev = curr if curr

        prev2&.text? && curr&.text? ? [comment, curr] : [curr]
      end
      .flatten
  end
end

class AppComponent < Component
  def initialize(**props)
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
          10
            .times
            .to_a
            .shuffle
            .first(7)
            .each { |i| li "hello #{i + rand(2)}", key: i }
        end
      end
    end
  end
end

def component(&block)
  Class.new(Component) do
    define_method(:should_update?) do |next_props, next_state|
      next_props != props
    end

    define_method(:render) do
      props = self.props

      Markup.build { instance_exec(**props, &block) }
    end
  end
end

class MyComponent < Component
  def render
    props[:children]
  end
end

App =
  component do |numbers:, children:|
    puts "Returning #{numbers}"
    div do
      ul { numbers.each { |i, j| li(key: i) { str "item #{j}" } } }
      MyComponent { span "hello" }
    end
  end

require "rexml/document"
require "stringio"

def format2(source)
  io = StringIO.new
  doc = REXML::Document.new(source)
  formatter = REXML::Formatters::Pretty.new
  # formatter.compact = true
  formatter.write(doc, io)
  io.rewind
  puts io.read.gsub(/(mayu-id='?)(\d+)/) { "#{$~[1]}\e[1;34m#{$~[2]}\e[0m" }
end

patch_sets = []
vdom = VDOM.new
tree =
  vdom.render(
    Descriptor.new(App, { numbers: [[1, 1], [2, 2], [3, 3]] })
  ) { |patches| patch_sets.push(patches) }
puts format2(tree.to_s)
# puts JSON.pretty_generate(tree.to_json)
tree =
  vdom.render(
    Descriptor.new(App, { numbers: [[2, 1], [4, 4], [3, 3], [1, 2]] })
  ) { |patches| patch_sets.push(patches) }
puts format2(tree.to_s)

tree =
  vdom.render(Descriptor.new(App, { numbers: [] })) do |patches|
    patch_sets.push(patches)
  end

puts format2(tree.to_s)
File.write("patches.json", JSON.pretty_generate(patch_sets))

# puts JSON.pretty_generate(tree.to_json)
# d1 = Descriptor.new(:TEXT, { text_content: "hello" })
# d2 = Descriptor.new(:TEXT, { text_content: "foobar" })
# vnode = init_vnode(ctx, d1)
# puts vnode
# vnode = patch_vnode(ctx, vnode, d2)
# puts vnode
