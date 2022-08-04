# typed: strict

require "bundler"
require "sorbet-runtime"
require "rexml/document"
require "stringio"
require "json"
require "cgi"

extend T::Sig

TAGS = T.let(JSON.parse(File.read("html-tags.json")), T::Array[String])
VOID_TAGS =
  T.let(JSON.parse(File.read("html-tags-void.json")), T::Array[String])

module VDOM2
  class Indexes
    extend T::Sig

    sig { params(indexes: T::Array[Integer]).void }
    def initialize(indexes = [])
      @indexes = indexes
    end

    sig { params(id: Integer).void }
    def append(id)
      @indexes.delete(id)
      @indexes.push(id)
    end

    sig { params(id: Integer).returns(T.nilable(Integer)) }
    def index(id) = @indexes.index(id)

    sig { params(id: Integer, before: T.nilable(Integer)).void }
    def insert_before(id, before)
      @indexes.delete(id)
      index = before && @indexes.index(before)
      index ? @indexes.insert(index, id) : @indexes.push(id)
      p @indexes
    end

    sig { params(id: Integer).returns(T.nilable(Integer)) }
    def next_sibling(id)
      if index = @indexes.index(id)
        @indexes[index.succ]
      end
    end

    sig { params(id: Integer).void }
    def remove(id) = @indexes.delete(id)

    sig { returns(T::Array[Integer]) }
    def to_a = @indexes
  end

  class RangeIterator
    extend T::Sig
    extend T::Generic
    include Enumerable

    Elem = type_member

    sig { returns(Integer) }
    attr_reader :start_idx
    sig { returns(Integer) }
    attr_reader :end_idx

    sig { params(array: T::Array[Elem]).void }
    def initialize(array)
      @array = array
      @start_idx = T.let(0, Integer)
      @end_idx = T.let(@array.length.pred, Integer)
    end

    sig { params(index: Integer).returns(T.nilable(Elem)) }
    def [](index)
      @array[index]
    end

    sig { override.params(block: T.proc.params(arg0: Elem).void).void }
    def each(&block)
      @start_idx.upto(@end_idx) { |i| x = @array[i] and yield x }
    end

    sig { returns(Integer) }
    def length = @end_idx - @start_idx
    sig { returns(T::Boolean) }
    def done? = @start_idx > @end_idx
    sig { returns(T.nilable(Elem)) }
    def start = @array[@start_idx]
    sig { returns(T.nilable(Elem)) }
    def end = @array[@end_idx]
    sig { void }
    def next_start = @start_idx += 1
    sig { void }
    def next_end = @end_idx -= 1
  end

  class UpdateContext
    extend T::Sig

    sig { returns(T::Array[T.untyped]) }
    attr_reader :patches

    sig { void }
    def initialize
      @patches = T.let([], T::Array[T.untyped])
      @parents = T.let([], T::Array[VNode])
      @dom_parents = T.let([], T::Array[VNode])
    end

    sig { returns(T.nilable(VNode)) }
    def parent = @parents.last

    sig { returns(T.nilable(VNode)) }
    def dom_parent = @dom_parents.last

    sig { params(vnode: VNode, blk: T.proc.void).void }
    def enter(vnode, &blk)
      dom_parent = vnode.descriptor.element?
      @parents.push(vnode)
      @dom_parents.push(vnode) if dom_parent
      yield
    ensure
      @dom_parents.pop if dom_parent
      @parents.pop
    end

    sig do
      params(
        vnode: VNode,
        before: T.nilable(VNode),
        after: T.nilable(VNode)
      ).void
    end
    def insert(vnode, before: nil, after: nil)
      # p caller.grep(/markup/).first(5)
      html = vnode.to_html
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

    sig do
      params(
        vnode: VNode,
        before: T.nilable(VNode),
        after: T.nilable(VNode)
      ).void
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

    sig { params(vnode: VNode, text: String).void }
    def text(vnode, text)
      add_patch(:text, id: vnode.id, text:)
    end

    sig { params(vnode: VNode).void }
    def remove(vnode)
      add_patch(:remove, id: vnode.id, parent: dom_parent&.id)
    end

    private

    sig { params(type: Symbol, args: T.untyped).void }
    def add_patch(type, **args)
      puts "\e[33m#{type}:\e[0m #{args.inspect}"
      @patches.push(args.merge(type:))
    end
  end

  class VTree
    extend T::Sig

    Id = T.type_alias { Integer }

    sig { returns(T::Array[T.untyped]) }
    attr_reader :patchsets

    sig { void }
    def initialize
      @root = T.let(nil, T.nilable(VNode))
      @patchsets = T.let([], T::Array[T.untyped])
      @id_counter = T.let(0, Id)
    end

    sig { params(descriptor: Descriptor).returns(T.nilable(VNode)) }
    def render(descriptor)
      ctx = UpdateContext.new
      @root = patch(ctx, @root, descriptor)
      @patchsets.push(ctx.patches)
      @root
    end

    sig { returns(Id) }
    def next_id!
      @id_counter.tap { @id_counter = @id_counter.succ }
    end

    private

    sig do
      params(
        ctx: UpdateContext,
        vnode: T.nilable(VNode),
        descriptor: T.nilable(Descriptor)
      ).returns(T.nilable(VNode))
    end
    def patch(ctx, vnode, descriptor)
      unless vnode
        return nil unless descriptor

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

    sig do
      params(ctx: UpdateContext, vnode: VNode, descriptor: Descriptor).returns(
        VNode
      )
    end
    def patch_vnode(ctx, vnode, descriptor)
      unless vnode.descriptor.same?(descriptor)
        raise "Can not patch different types!"
      end

      if component = vnode.component
        if component.should_update?(descriptor.props, component.__next_state)
          vnode.descriptor = descriptor
          component.__props = descriptor.props
          component.__state = component.__next_state.clone
          descriptors =
            add_comments_between_texts(Array(component.render).compact)

          ctx.enter(vnode) do
            vnode.children =
              update_children(ctx, vnode.children.compact, descriptors)
          end

          component.did_update
        end

        return vnode
      end

      type = descriptor.type

      if type.is_a?(Proc)
        vnode.descriptor = descriptor
        descriptors = Array(type.call(**descriptor.props)).compact

        ctx.enter(vnode) do
          vnode.children =
            update_children(ctx, vnode.children.compact, descriptors)
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
              vnode.children =
                update_children(ctx, vnode.children, descriptor.children)
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
          ctx.text(vnode, "")
        else
          puts "got here"
        end
      end

      vnode.descriptor = descriptor

      vnode
    end

    sig do
      params(ctx: UpdateContext, vnodes: T::Array[VNode]).returns(NilClass)
    end
    def remove_vnodes(ctx, vnodes)
      vnodes.each { |vnode| remove_vnode(ctx, vnode) }
      nil
    end

    sig do
      params(
        ctx: UpdateContext,
        descriptor: Descriptor,
        nested: T::Boolean
      ).returns(VNode)
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

    sig do
      params(ctx: UpdateContext, vnode: VNode, patch: T::Boolean).returns(
        NilClass
      )
    end
    def remove_vnode(ctx, vnode, patch: true)
      ctx.remove(vnode) if patch
      vnode.children.map { remove_vnode(ctx, _1, patch: false) }
      vnode.unmount
      nil
    end

    sig { params(descriptors: T::Array[Descriptor]).void }
    def check_duplicate_keys(descriptors)
      keys = descriptors.map(&:key).compact
      duplicates = keys.reject { keys.rindex(_1) == keys.index(_1) }.uniq
      duplicates.each do |key|
        puts "\e[31mDuplicate keys detected: '#{key}'. This may cause an update error.\e[0m"
      end
    end

    sig { params(vnode: VNode, descriptor: Descriptor).returns(T::Boolean) }
    def same?(vnode, descriptor)
      vnode.descriptor.same?(descriptor)
    end

    sig do
      params(
        ctx: UpdateContext,
        vnodes: T::Array[VNode],
        descriptors: T::Array[Descriptor]
      ).returns(T::Array[VNode])
    end
    def update_children(ctx, vnodes, descriptors)
      check_duplicate_keys(descriptors)

      old_ch = vnodes
      new_ch = descriptors
      old_start_idx = 0
      new_start_idx = 0
      old_end_idx = old_ch.length.pred
      new_end_idx = new_ch.length.pred

      indexes = Indexes.new(vnodes.map(&:id))
      moved_ids = Set.new
      children = []

      while old_start_idx <= old_end_idx && new_start_idx <= new_end_idx
        old_start_idx += 1 and next unless old_start_vnode =
          old_ch[old_start_idx]
        old_end_idx -= 1 and next unless old_end_vnode = old_ch[old_end_idx]
        new_start_vnode = T.must(new_ch[new_start_idx])
        new_end_vnode = T.must(new_ch[new_end_idx])

        if same?(old_start_vnode, new_start_vnode)
          patch_vnode(ctx, old_start_vnode, new_start_vnode)
          children.push(old_start_vnode)
          old_start_idx += 1
          new_start_idx += 1
          next
        end

        if same?(old_end_vnode, new_end_vnode)
          patch_vnode(ctx, old_end_vnode, new_end_vnode)
          children.push(old_end_vnode)
          old_end_idx -= 1
          new_end_idx -= 1
          next
        end

        if same?(old_start_vnode, new_end_vnode)
          patch_vnode(ctx, old_start_vnode, new_end_vnode)
          ctx.move(old_start_vnode, after: old_end_vnode)
          indexes.insert_before(
            old_start_vnode.id,
            indexes.next_sibling(old_end_vnode.id)
          )
          children.push(old_start_vnode)
          old_start_idx += 1
          new_end_idx -= 1
          next
        end

        if same?(old_end_vnode, new_start_vnode)
          patch_vnode(ctx, old_end_vnode, new_start_vnode)
          ctx.move(old_end_vnode, before: old_start_vnode)
          indexes.insert_before(old_end_vnode.id, old_start_vnode.id)
          children.push(old_end_vnode)
          old_end_idx -= 1
          new_start_idx += 1
          next
        end

        old_key_to_idx = build_key_index_map(old_ch, old_start_idx, old_end_idx)

        idx_in_old = new_start_vnode.key && old_key_to_idx[new_start_vnode.key]
        vnode_to_move = idx_in_old && old_ch[idx_in_old]

        unless vnode_to_move
          vnode = init_vnode(ctx, new_start_vnode)
          ctx.insert(vnode, before: old_start_vnode)
          indexes.insert_before(vnode.id, old_start_vnode.id)
          children.push(vnode)
          new_start_idx += 1
          next
        end

        if same?(vnode_to_move, new_start_vnode)
          moved_ids.add(vnode_to_move.id)
          vnode = patch_vnode(ctx, vnode_to_move, new_start_vnode)
          ctx.move(vnode_to_move, before: old_start_vnode)
          indexes.insert_before(vnode_to_move.id, old_start_vnode.id)
          children.push(vnode_to_move)
          new_start_idx += 1
          next
        end

        puts "Same key but different element, treat as new element"
        vnode = init_vnode(ctx, new_start_vnode)
        ctx.insert(vnode, before: old_start_vnode)
        indexes.insert_before(vnode.id, old_start_vnode.id)
        children.push(vnode)

        new_start_idx += 1
      end

      if old_start_idx > old_end_idx
        # TODO: something about ref elms from the new children
        #  refElm = isUndef(newCh[newEndIdx + 1]) ? null : newCh[newEndIdx + 1].elm
        ref_elm = vnodes[old_end_idx.succ]
        descriptors_to_add = new_ch.slice(new_start_idx..new_end_idx)
        if descriptors_to_add
          descriptors_to_add.each do |descriptor|
            new_vnode = init_vnode(ctx, descriptor)
            ctx.insert(new_vnode, before: ref_elm)
            indexes.insert_before(new_vnode.id, ref_elm&.id)
            children.push(new_vnode)
          end
        end
      elsif new_start_idx > new_end_idx
        vnodes_to_remove = old_ch.slice(old_start_idx..old_end_idx)
        if vnodes_to_remove
          vnodes_to_remove.each do |vnode|
            remove_vnode(ctx, vnode) unless moved_ids.include?(vnode.id)
          end
        end
      end

      children.sort_by { indexes.index(_1.id) || Float::INFINITY }
    end

    sig do
      params(
        children: T::Array[VDOM2::VNode],
        start_index: Integer,
        end_index: Integer
      ).returns(T::Hash[Integer, T.untyped])
    end
    def build_key_index_map(children, start_index, end_index)
      keymap = {}

      start_index.upto(end_index) do |i|
        if key = children[i]&.descriptor&.key
          keymap[key] = i
        end
      end

      keymap
    end

    sig do
      params(descriptors: T::Array[Descriptor]).returns(T::Array[Descriptor])
    end
    def add_comments_between_texts(descriptors)
      comment = Descriptor.comment
      prev = T.let(nil, T.nilable(Descriptor))

      descriptors
        .map
        .with_index do |curr, i|
          prev2 = prev
          prev = curr if curr

          prev2&.text? && curr.text? ? [comment, curr] : [curr]
        end
        .flatten
    end
  end

  class VNode
    extend T::Sig

    sig { returns(Descriptor) }
    attr_accessor :descriptor
    sig { returns(T.nilable(Component)) }
    attr_accessor :component
    sig { returns(T::Array[VNode]) }
    attr_accessor :children

    sig { returns(VTree::Id) }
    attr_reader :id

    sig { params(vtree: VTree, descriptor: Descriptor).void }
    def initialize(vtree, descriptor)
      @id = T.let(vtree.next_id!, VTree::Id)
      @vtree = vtree
      @descriptor = descriptor
      @component = T.let(nil, T.nilable(Component))
      @children = T.let([], T::Array[VNode])
    end

    sig { returns(T.nilable(Component)) }
    def init_component
      @component ||= @descriptor.new_component(self)
    end

    sig { void }
    def mount
      @component&.mount
    end

    sig { void }
    def unmount
      @component&.unmount
    end

    sig { returns(T.untyped) }
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

    sig { returns(String) }
    def inspect
      "#<#{self.class.name} id=#{id} type=#{descriptor.type.inspect} children=#{children.length}>"
    end

    sig { returns(String) }
    def inspect2
      "\e[34;7m#{id}\e[0;7m #{text_content}\e[0m"
    end

    sig { params(level: Integer).returns(String) }
    def to_s(level = 0)
      return "" if descriptor.comment?

      if descriptor.text?
        return "  " * level + "\e[34m#{id}\e[0m #{descriptor.text}"
      end
      [
        "  " * level + "\e[34m#{id}\e[0m #{descriptor.type}",
        *children.map { _1.to_s(level.succ) }
      ].compact.reject(&:empty?).join("\n")
    end

    sig { returns(String) }
    def text_content
      if descriptor.text?
        content = descriptor.text

        if content.empty?
          return "&ZeroWidthSpace;"
        else
          return CGI.escape_html(content)
        end
      end

      children.map(&:text_content).reject(&:empty?).join
    end

    sig { returns(String) }
    def to_html
      return children.map(&:to_html).join if component
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
        format(
          "<%<type>s%<attrs>s>%<children>s</%<type>s>",
          type:,
          attrs:,
          children: @children.map(&:to_html).join
        )
      end
    end

    sig { returns(T.untyped) }
    def id_tree
      if component
        children.first&.id_tree
      else
        ch = children.map(&:id_tree).compact
        ch.empty? ? { id: } : { id:, ch: }
      end
    end

    sig { void }
    def enqueue_update!
    end
  end

  class Component
    extend T::Sig

    Props = T.type_alias { T::Hash[Symbol, T.untyped] }
    State = T.type_alias { T::Hash[Symbol, T.untyped] }

    sig { returns(Props) }
    def props = @__props
    sig { params(__props: Props).void }
    attr_writer :__props
    sig { params(__state: State).void }
    attr_writer :__state

    sig { returns(State) }
    def state = @__state
    sig { returns(State) }
    def __next_state = @__next_state

    sig { params(vnode: VNode, props: T.untyped).void }
    def initialize(vnode, **props)
      @__vnode = vnode
      @__props = props
      @__state = T.let({}.freeze, State)
      @__next_state = T.let({}.freeze, State)
    end

    sig { params(next_props: Props, next_state: State).returns(T::Boolean) }
    def should_update?(next_props, next_state)
      !(props == next_props && state == next_state)
    end

    sig { void }
    def enqueue_update! = @__vnode.enqueue_update!

    sig { void }
    def mount = nil
    sig { void }
    def unmount = nil
    sig { void }
    def did_update = nil
    sig { returns(T.nilable(Descriptor)) }
    def render = nil
  end

  class Descriptor
    extend T::Sig

    LambdaComponent =
      T.type_alias do
        T.proc.params(kwargs: Props).returns(T.nilable(Descriptor))
      end

    Type =
      T.type_alias { T.any(Symbol, T.class_of(Component), LambdaComponent) }

    Props = T.type_alias { T::Hash[Symbol, T.untyped] }

    TEXT = :TEXT
    COMMENT = :COMMENT

    sig { returns(T.untyped) }
    attr_reader :key
    sig { returns(Type) }
    attr_reader :type
    sig { returns(Props) }
    attr_reader :props

    sig { params(type: Type, props: Props, children: T::Array[T.untyped]).void }
    def initialize(type, props = {}, children = [])
      @type = type
      @props =
        T.let(
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
          ),
          Props
        )
      @key = T.let(props.delete(:key), T.untyped)
    end

    sig { params(vnode: VNode).returns(T.nilable(Component)) }
    def new_component(vnode)
      @type.new(vnode, **props) if @type.is_a?(Class) && @type < Component
    end

    sig { returns(Descriptor) }
    def self.comment = new(COMMENT)

    sig { returns(String) }
    def text = props[:text_content].to_s
    sig { returns(T::Boolean) }
    def text? = @type == TEXT
    sig { returns(T::Boolean) }
    def comment? = @type == COMMENT
    sig { returns(T::Boolean) }
    def element? = @type.is_a?(Symbol) && !text? && !comment?
    sig { returns(T::Array[Descriptor]) }
    def children = props[:children]
    sig { returns(T::Boolean) }
    def children? = children.any?

    sig { returns(String) }
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

    sig { params(other: Descriptor).returns(T::Boolean) }
    def same?(other)
      if key == other.key && type == other.type
        type == :input ? props[:type] == props[:type] : true
      else
        false
      end
    end
  end

  module H
    extend T::Sig

    sig do
      params(
        type: VDOM2::Descriptor::Type,
        args: T.untyped,
        props: T.untyped,
        block:
          T.nilable(
            T.proc.returns(
              T.nilable(T.any(VDOM2::Descriptor, T::Array[VDOM2::Descriptor]))
            )
          )
      ).returns(VDOM2::Descriptor)
    end
    def h(type, *args, **props, &block)
      Descriptor.new(type, props, args.concat([block&.call].flatten.compact))
    end
  end
end

sig { params(source: String).void }
def print_xml(source)
  io = StringIO.new
  doc = REXML::Document.new(source)
  formatter = REXML::Formatters::Pretty.new
  formatter.compact = true
  formatter.write(doc, io)
  io.rewind
  puts io.read.gsub(/(mayu-id='?)(\d+)/) { "#{$~[1]}\e[1;34m#{$~[2]}\e[0m" }
end

class MyApp < VDOM2::Component
  include VDOM2::H

  sig { returns(T.nilable(VDOM2::Descriptor)) }
  def render
    h(:ul) do
      props[:items].map do |item|
        h(item[:type] || :li, key: item[:id]) { item[:title] }
      end
    end
  end
end

extend VDOM2::H

@vtree = VDOM2::VTree.new

def render(desc)
  root = T.must(@vtree.render(desc))

  return unless root
  @vtree.patchsets.last.each do |patch|
    puts "#{patch[:type].to_s.ljust(10)} #{patch.except(:type).inspect}"
  end
  print_xml(root.to_html)
  puts root
end

class Quotes < VDOM2::Component
  include VDOM2::H

  sig { returns(VDOM2::Descriptor) }
  def render
    h(:div) do
      [h(:h2, "Asd"), h(:ul) { [h(:li, "xoo"), h(:li, "xar"), h(:li, "xaz")] }]
    end
  end
end

class Asd < VDOM2::Component
  include VDOM2::H

  sig { returns(VDOM2::Descriptor) }
  def render
    h(:div) { [h(:h2, "Asd"), h(:span, "lol")] }
  end
end

render(
  h(:div) do
    [h(:ul) { [h(:li, "foo"), h(:li, "bar")] }, h(:section) { h(Quotes) }]
  end
)

render(
  h(:div) do
    [
      h(:ul) { [h(:li, "foo"), h(:li, "bar")] },
      h(:div) { h(:h2, "haj") },
      h(:div) { h(:span, "hopp") },
      h(:div) { h(:span, "hkarg") },
      h(:section) { h(Asd) }
    ]
  end
)

render(
  h(:div) do
    [
      h(:ul) { [h(:li, "foo"), h(:li, "bar")] },
      h(:div) { h(:h2, "haj") },
      h(:div) { h(:span, "hopp") },
      h(:section) { h(Asd) },
      h(:div) { h(:span, "hkarg") }
    ]
  end
)

__END__
extend VDOM2::H

@vtree = VDOM2::VTree.new
@outputs = []

def hax(**props)
  root = T.must(@vtree.render(h(MyApp, **props)))
  return unless root
  @outputs << root.to_html
  puts root
end

hax(
  items: [
    { id: 0, title: "Item 0" },
    { id: 1, title: "Item 1" },
    { id: 2, title: "Item 2" },
    { id: 3, title: "Item 3" },
    { id: 4, title: "Item 4" },
    { id: 5, title: "Item 5" },
    { id: 6, title: "Item 6" },
  ]
)

hax(
  items: [
    { id: 0, title: "Item 0" },
    { id: 1, title: "Item 1" },
    { id: 2, title: "Item 2" },
    { id: 3, title: "Item 3" },
    { id: 4, title: "Item 4" },
    { id: 5, title: "Item 5" },
  ]
)

hax(
  items: [
    { id: 0, title: "Item 0" },
    { id: 1, title: "Item 1" },
    { id: 3, title: "Item 3", type: :p },
    { id: 4, title: "Item 4" },
    { id: 2, title: "Item 2" },
    { id: 5, title: "Item 5" },
  ]
)

hax(
  items: [
    { id: 0, title: "Item 0" },
    { id: 1, title: "Item 1" },
    { id: 2, title: "Item 2" },
    { id: 3, title: "Item 3" },
    { id: 4, title: "Item 4" },
    { id: 5, title: "Item 5" },
    { id: 6, title: "Item 6" },
  ]
)

hax(
  items: [
    { id: 4, title: "Item 4" },
    { id: 13, title: "Item 13" },
    { id: 7, title: "Item 7" },
    { id: 12, title: "Item 12" },
    { id: 9, title: "Item 9" },
    { id: 15, title: "Item 15" },
    { id: 19, title: "Item 19" },
    { id: 6, title: "Item 6" },
    { id: 2, title: "Item 2" },
    { id: 11, title: "Item 11" },
    { id: 17, title: "Item 17" },
    { id: 3, title: "Item 3" },
    { id: 16, title: "Item 16" },
    { id: 18, title: "Item 18" },
    { id: 8, title: "Item 8" },
    { id: 0, title: "Item 0" },
    { id: 14, title: "Item 14" },
    { id: 1, title: "Item 1" },
    { id: 10, title: "Item 10" },
    { id: 5, title: "Item 5" },
  ]
)

hax(
  items: [
    { id: 30, title: "Item 30" },
    { id: 16, title: "Item 16" },
    { id: 24, title: "Item 24" },
    { id: 14, title: "Item 14" },
    { id: 18, title: "Item 18" },
    { id: 21, title: "Item 21" },
    { id: 22, title: "Item 22" },
    { id: 13, title: "Item 13" },
    { id: 17, title: "Item 17" },
    { id: 19, title: "Item 19" },
    { id: 15, title: "Item 15" },
    { id: 26, title: "Item 26" },
    { id: 20, title: "Item 20" },
    { id: 27, title: "Item 27" },
    { id: 28, title: "Item 28" },
    { id: 32, title: "Item 32" },
    { id: 31, title: "Item 31" },
    { id: 11, title: "Item 11" },
    { id: 9, title: "Item 9" },
    { id: 23, title: "Item 23" },
    { id: 8, title: "Item 8" },
    { id: 29, title: "Item 29" },
    { id: 10, title: "Item 10" },
    { id: 12, title: "Item 12" },
    { id: 25, title: "Item 25" },
  ]
)

sig {params(s: String).returns(String)}
def striphtml(s) = s.gsub(/<.*?>/, "\n").gsub(/$+/, "\n")

File.write(
  "patches.json",
  JSON.pretty_generate(
    @vtree.patchsets.zip(@outputs).map do |patches, output|
      { patches:, output: }
    end
  )
)
puts @outputs
