# typed: strict

require "async/queue"
require "nanoid"
require_relative "../component"
require_relative "descriptor"
require_relative "dom"
require_relative "vnode"
require_relative "css_attributes"
require_relative "update_context"
require_relative "id_generator"
require_relative "../session"
require_relative "../ref_counter"
require_relative "indexes"

module Mayu
  module VDOM
    class VTree
      extend T::Sig

      class Updater
        extend T::Sig

        # This value limits how many updates per second we can make.
        DEFAULT_UPDATES_PER_SECOND = 20

        sig { params(vtree: VTree, updates_per_second: Integer).void }
        def initialize(vtree, updates_per_second: DEFAULT_UPDATES_PER_SECOND)
          @vtree = vtree
          @updates_per_second = updates_per_second
        end

        sig { params(handler_id: String, payload: T.untyped).void }
        def handle_callback(handler_id, payload = {})
          p(["Handle callback", payload])
          @vtree.handle_callback(handler_id, payload)
        end

        sig do
          params(
            task: Async::Task,
            block: T.proc.params(arg0: [Symbol, T.untyped]).void
          ).returns(Async::Task)
        end
        def run(task: Async::Task.current, &block)
          task.async(annotation: "VTree updater") do |task|
            assets = T::Set[String].new

            loop do
              @vtree.update_queue.wait while @vtree.update_queue.empty?

              ctx = UpdateContext.new

              start_at = Time.now

              @vtree.update_queue.size.times do
                case @vtree.update_queue.dequeue
                in [:replace_root, descriptor]
                  @vtree.render(descriptor, ctx:)
                in [:navigate, path]
                  yield [:navigate, path]
                in [:exception, error]
                  yield [:exception, error]
                in [:pong, timestamp]
                  yield [:pong, timestamp]
                in VNode => vnode
                  next if vnode.removed?
                  # puts "Patching #{vnode.component.inspect}"
                  next unless vnode.component&.dirty?
                  @vtree.patch(ctx, vnode, vnode.descriptor, lifecycles: true)
                end
              end

              stylesheets = []

              @vtree.assets.each do |asset|
                next if assets.include?(asset)
                next unless asset.end_with?(".css")
                stylesheets.push(asset)
                assets.add(asset)
              end

              patches = ctx.patches + stylesheet_patch(stylesheets)
              yield [:patch, patches] unless patches.empty?
              puts "\e[34mRendering took %.3fs\e[0m" % (Time.now - start_at)

              sleep 1.0 / @updates_per_second
              puts "@vtree item: #{@vtree.update_queue.size}"
            end
          rescue => e
            puts e.message
            puts e.backtrace
            error = {
              type: e.class.name,
              message: e.message,
              backtrace: e.backtrace
            }

            yield [:exception, error]
          end
        end

        sig do
          params(stylesheets: T::Array[String]).returns(T::Array[T.untyped])
        end
        def stylesheet_patch(stylesheets)
          return [] if stylesheets.empty?

          paths = stylesheets.map { "/__mayu/static/#{_1}" }

          [{ type: :stylesheet, paths: }]
        end
      end

      sig { returns(Session) }
      attr_reader :session
      sig { returns(Async::Queue) }
      attr_reader :update_queue
      sig { returns(T.nilable(VNode)) }
      attr_reader :root

      sig { returns(T::Array[String]) }
      def assets = @asset_refs.keys

      sig { params(session: Session, task: Async::Task).void }
      def initialize(session:, task: Async::Task.current)
        @root = T.let(nil, T.nilable(VNode))
        @id_generator = T.let(IdGenerator.new, IdGenerator)
        @session = T.let(session, Session)

        @handlers = T.let({}, T::Hash[String, Component::HandlerRef])

        @update_queue = T.let(Async::Queue.new, Async::Queue)

        @update_semaphore =
          T.let(Async::Semaphore.new(parent: task), Async::Semaphore)

        @sent_stylesheets = T.let(Set.new, T::Set[String])
        @asset_refs = T.let(RefCounter.new, RefCounter[String])
      end

      sig { returns(T::Array[T.untyped]) }
      def marshal_dump
        [@root, @id_generator, @sent_stylesheets]
      end

      sig { params(a: T::Array[T.untyped]).void }
      def marshal_load(a)
        @root, @id_generator, @sent_stylesheets = a
        @handlers = {}
        @update_queue = Async::Queue.new
        @update_semaphore = Async::Semaphore.new
        @asset_refs = T.let(RefCounter.new, RefCounter[String])
        @root.instance_variable_set(:@vtree, self)
      end

      sig do
        params(
          descriptor: Descriptor,
          ctx: UpdateContext,
          lifecycles: T::Boolean
        ).returns(UpdateContext)
      end
      def render(descriptor, ctx: UpdateContext.new, lifecycles: true)
        start_at = Time.now
        @root = patch(ctx, @root, descriptor, lifecycles:)
        ctx
      end

      sig { params(descriptor: Descriptor).void }
      def replace_root(descriptor)
        @update_queue.enqueue([:replace_root, descriptor])
      end

      sig { params(handler_id: String, payload: T.untyped).void }
      def handle_callback(handler_id, payload = {})
        case handler_id
        when "ping"
          @update_queue.enqueue([:pong, payload[:timestamp]])
          return
        when "navigate"
          navigate(payload[:path])
          return
        end

        @handlers
          .fetch(handler_id) do
            raise KeyError, "Handler not found: #{handler_id}"
          end
          .call(payload)
      rescue => e
        puts e.message
        puts e.backtrace
        error = {
          type: e.class.name,
          message: e.message,
          backtrace: e.backtrace
        }
        @update_queue.enqueue([:exception, error])
      end

      sig { returns(String) }
      def to_html
        @root&.to_html.to_s
      end

      sig { params(exclude_components: T::Boolean).returns(String) }
      def inspect_tree(exclude_components: false)
        @root&.inspect_tree(exclude_components:).to_s
      end

      sig { returns(T.untyped) }
      def id_tree
        @root&.id_tree
      end

      sig { params(vnode: VNode).void }
      def enqueue_update!(vnode)
        component = vnode.component
        return unless component
        return if component.dirty?

        component.dirty!
        @update_queue.enqueue(vnode)
      end

      sig { returns(IdGenerator::Type) }
      def next_id! = @id_generator.next!

      sig { params(path: String).void }
      def navigate(path)
        @update_queue.enqueue([:navigate, path])
      end

      sig do
        params(
          ctx: UpdateContext,
          vnode: T.nilable(VNode),
          descriptor: T.nilable(Descriptor),
          lifecycles: T::Boolean
        ).returns(T.nilable(VNode))
      end
      def patch(ctx, vnode, descriptor, lifecycles:)
        unless vnode
          return nil unless descriptor

          vnode = init_vnode(ctx, descriptor, lifecycles:)
          ctx.insert(vnode)
          return vnode
        end

        return remove_vnode(ctx, vnode, lifecycles:) unless descriptor

        if vnode.descriptor.same?(descriptor)
          patch_vnode(ctx, vnode, descriptor, lifecycles:)
        else
          remove_vnode(ctx, vnode, lifecycles:)
          vnode = init_vnode(ctx, descriptor, lifecycles:)
          ctx.insert(vnode)
          return vnode
        end
      end

      private

      sig do
        params(
          ctx: UpdateContext,
          vnode: VNode,
          descriptor: Descriptor,
          lifecycles: T::Boolean
        ).returns(VNode)
      end
      def patch_vnode(ctx, vnode, descriptor, lifecycles:)
        unless vnode.descriptor.same?(descriptor)
          raise "Can not patch different types!"
        end

        if component = vnode.component
          if component.should_update?(descriptor.props, component.next_state)
            vnode.descriptor = descriptor
            prev_props, prev_state = component.props, component.state
            component.props = descriptor.props
            component.state = component.next_state.clone
            descriptors =
              add_comments_between_texts(Array(component.render).compact)

            ctx.enter(vnode) do
              vnode.children =
                update_children(
                  ctx,
                  vnode.children.compact,
                  descriptors,
                  lifecycles:
                )
            end

            update_stylesheet(ctx, component)

            component.did_update(prev_props, prev_state) if lifecycles
          end

          return vnode
        end

        type = descriptor.type

        if type.is_a?(Proc)
          vnode.descriptor = descriptor
          descriptors = Array(type.call(**descriptor.props)).compact

          ctx.enter(vnode) do
            vnode.children =
              update_children(
                ctx,
                vnode.children.compact,
                descriptors,
                lifecycles:
              )
          end

          return vnode
        end

        return vnode if vnode.descriptor == descriptor

        if descriptor.text?
          unless vnode.descriptor.text == descriptor.text
            if append = append_part(vnode.descriptor.text, descriptor.text)
              ctx.text(vnode, append, append: true)
            else
              ctx.text(vnode, descriptor.text)
            end
            vnode.descriptor = descriptor
            return vnode
          end
        else
          if vnode.descriptor.children? && descriptor.children?
            if vnode.descriptor.children != descriptor.children
              ctx.enter(vnode) do
                vnode.children =
                  update_children(
                    ctx,
                    vnode.children,
                    descriptor.children,
                    lifecycles:
                  )
              end
            end
          elsif descriptor.children?
            check_duplicate_keys(descriptor.children)
            puts "adding new children"

            ctx.enter(vnode) do
              vnode.children =
                add_comments_between_texts(descriptor.children).map do
                  init_vnode(ctx, _1, lifecycles:).tap do |child|
                    ctx.insert(child)
                  end
                end
            end
          elsif vnode.children.length > 0
            ctx.enter(vnode) do
              vnode.children.each { remove_vnode(ctx, _1, lifecycles:) }
            end
            vnode.children = []
          elsif vnode.descriptor.text?
            ctx.text(vnode, "")
          else
            # Everything seems to be exactly the same
          end
        end

        update_handlers(vnode.props, descriptor.props)
        update_attributes(ctx, vnode, vnode.props, descriptor.props)

        vnode.descriptor = descriptor

        vnode
      end

      sig do
        params(
          ctx: UpdateContext,
          vnodes: T::Array[VNode],
          lifecycles: T::Boolean
        ).returns(NilClass)
      end
      def remove_vnodes(ctx, vnodes, lifecycles:)
        vnodes.each { |vnode| remove_vnode(ctx, vnode, lifecycles:) }
        nil
      end

      sig { params(ctx: UpdateContext, component: Component::Wrapper).void }
      def update_stylesheet(ctx, component)
        # TODO: Make this more generic..
        # Would be great if we could ask the dependency graph
        # of what direct dependencies this component has, and
        # get their assets...
        # Images for example, could be preloaded:
        # https://web.dev/preload-responsive-images/
        if stylesheet = component.stylesheet
          stylesheet.assets.each { |asset| @asset_refs.acquire(asset.filename) }
        end
      end

      sig do
        params(
          ctx: UpdateContext,
          descriptor: Descriptor,
          lifecycles: T::Boolean,
          nested: T::Boolean
        ).returns(VNode)
      end
      def init_vnode(ctx, descriptor, lifecycles:, nested: false)
        vnode = VNode.new(self, ctx.dom_parent_id, descriptor)

        component = vnode.init_component

        children =
          if component
            Array(component.render).compact
          else
            descriptor.props[:children]
          end

        update_stylesheet(ctx, component) if component
        # puts "\e[32mInitializing vnode #{vnode.id} #{vnode.descriptor.type} with #{children.length} children\e[0m"

        ctx.enter(vnode) do
          vnode.children =
            add_comments_between_texts(children).map do
              init_vnode(ctx, _1, lifecycles:, nested: true)
            end
        end

        vnode.component&.mount if lifecycles

        update_handlers({}, vnode.props)

        vnode
      end

      sig do
        params(
          ctx: UpdateContext,
          vnode: VNode,
          lifecycles: T::Boolean,
          patch: T::Boolean
        ).returns(NilClass)
      end
      def remove_vnode(ctx, vnode, lifecycles:, patch: true)
        # puts "\e[31mRemoving vnode #{vnode.id} #{vnode.descriptor.type}\e[0m"

        vnode.component&.unmount if lifecycles
        vnode.remove!
        ctx.remove(vnode) if patch
        vnode.children.map { remove_vnode(ctx, _1, lifecycles:, patch: false) }
        update_handlers(vnode.props, {})
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
          descriptors: T::Array[Descriptor],
          lifecycles: T::Boolean
        ).returns(T::Array[VNode])
      end
      def update_children(ctx, vnodes, descriptors, lifecycles:)
        check_duplicate_keys(descriptors)

        vnodes = vnodes.compact
        descriptors = descriptors.compact
        old_ids = vnodes.map(&:id)

        indexes = Indexes.new(vnodes.map(&:id))

        new_children =
          T.let(
            descriptors.map.with_index do |descriptor, i|
              vnode = vnodes.find { _1.same?(descriptor) }

              if vnode
                vnodes.delete(vnode)
                patch_vnode(ctx, vnode, descriptor, lifecycles:)
              else
                init_vnode(ctx, descriptor, lifecycles:)
              end
            end,
            T::Array[VNode]
          )

        # This is very inefficient.
        # I tried to get the algorithm from snabbdom/vue to work,
        # but it's not very easy to get right.
        # I always got some weird ordering issues and it's tricky to debug.
        # Fun stuff for later though.

        all_vnodes = vnodes + new_children

        new_children.each_with_index do |vnode, expected_index|
          new_indexes = Indexes.new(indexes.to_a - vnodes.map(&:id))
          current_index = indexes.index(vnode.id)

          before_id = indexes[expected_index]
          before = before_id && all_vnodes.find { _1.id == before_id } || nil

          if old_ids.include?(vnode.id)
            unless current_index == expected_index
              ctx.move(vnode, before:)
              indexes.insert_before(vnode.id, before_id)
            end
          else
            ctx.insert(vnode, before:)
            indexes.insert_before(vnode.id, before_id)
          end
        end

        vnodes.each { |vnode| remove_vnode(ctx, vnode, lifecycles:) }

        new_children
      end

      sig do
        params(
          children: T::Array[VNode],
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

      sig do
        params(old_props: Component::Props, new_props: Component::Props).void
      end
      def update_handlers(old_props, new_props)
        old_handlers = old_props.keys.select { _1.start_with?("on_") }
        new_handlers = new_props.keys.select { _1.start_with?("on_") }

        # FIXME: If the same handler id is used somewhere else,
        # it will be cleared too.
        removed_handlers = old_handlers - new_handlers

        old_props
          .values_at(*T.unsafe(removed_handlers))
          .select { _1.is_a?(Component::HandlerRef) }
          .each { |handler| @handlers.delete(handler.id) }

        new_props
          .values_at(*T.unsafe(new_handlers))
          .select { _1.is_a?(Component::HandlerRef) }
          .each { |handler| @handlers[handler.id] = handler }
      end

      sig do
        params(
          ctx: UpdateContext,
          vnode: VNode,
          old_props: Component::Props,
          new_props: Component::Props
        ).void
      end
      def update_attributes(ctx, vnode, old_props, new_props)
        removed = old_props.keys - new_props.keys - [:children]

        new_props.each do |attr, value|
          next if attr == :children

          old_value = old_props[attr]
          next if value == old_props[attr]

          removed.push(attr) and next unless value

          if attr == :style && old_value.is_a?(Hash) && value.is_a?(Hash)
            CSSAttributes.new(**old_value).patch(
              ctx,
              vnode,
              CSSAttributes.new(**value)
            )
            next
          end

          if HTML.boolean_attribute?(attr) || value == true
            ctx.set_attribute(vnode, attr.to_s, attr.to_s)
          else
            ctx.set_attribute(vnode, attr.to_s, value.to_s)
          end
        end

        removed.uniq.each { |attr| ctx.remove_attribute(vnode, attr.to_s) }
      end

      sig { params(str1: String, str2: String).returns(T.nilable(String)) }
      def append_part(str1, str2)
        return nil if str1.strip.empty? || str1.length >= str2.length
        return nil unless str2.slice(0...str1.length) == str1
        str2.slice(str1.length..-1)
      end
    end
  end
end
