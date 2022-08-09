# typed: strict

require "async/queue"
require "nanoid"
require_relative "component"
require_relative "descriptor"
require_relative "dom"
require_relative "vnode"
require_relative "css_attributes"
require_relative "update_context"
require_relative "id_generator"

module Mayu
  module VDOM
    class VTree
      extend T::Sig

      class Indexes
        extend T::Sig
        extend T::Generic

        Elem = type_member

        sig { params(indexes: T::Array[Elem]).void }
        def initialize(indexes = [])
          @indexes = indexes
        end

        sig { params(id: Elem).void }
        def append(id)
          @indexes.delete(id)
          @indexes.push(id)
        end

        sig { params(index: Integer).returns(T.nilable(Elem)) }
        def [](index) = @indexes[index]

        sig { params(id: Elem).returns(T.nilable(Integer)) }
        def index(id) = @indexes.index(id)
        sig { params(id: Elem).returns(T.nilable(Integer)) }
        def rindex(id) = @indexes.rindex(id)

        sig { params(id: Elem, after: T.nilable(Elem)).void }
        def insert_after(id, after)
          insert_before(id, after && next_sibling(after))
        end

        sig { params(id: Elem, before: T.nilable(Elem)).void }
        def insert_before(id, before)
          @indexes.delete(id)
          index = before && @indexes.index(before)
          index ? @indexes.insert(index, id) : @indexes.push(id)
        end

        sig { params(id: Elem).returns(T.nilable(Elem)) }
        def next_sibling(id)
          if index = @indexes.index(id)
            @indexes[index.succ]
          end
        end

        sig { params(id: Elem).void }
        def remove(id) = @indexes.delete(id)

        sig { returns(T::Array[Elem]) }
        def to_a = @indexes
      end

      sig { returns(Async::Queue) }
      attr_reader :on_update
      sig { returns(Fetch) }
      attr_reader :fetch

      sig do
        params(store: State::Store, fetch: Fetch, task: Async::Barrier).void
      end
      def initialize(store:, fetch:, task: Async::Task.current)
        @root = T.let(nil, T.nilable(VNode))
        @id_generator = T.let(IdGenerator.new, IdGenerator)
        @fetch = fetch

        @handlers = T.let({}, T::Hash[String, Component::HandlerRef])

        @update_queue = T.let(Async::Queue.new, Async::Queue)
        @on_update = T.let(Async::Queue.new, Async::Queue)

        @update_semaphore =
          T.let(Async::Semaphore.new(parent: task), Async::Semaphore)

        @sent_stylesheets = T.let(Set.new, T::Set[String])

        @store = store

        @update_task =
          T.let(
            task.async(annotation: "VTree updater") do |task|
              loop do
                sleep 0.05

                next if @update_queue.empty?

                ctx = UpdateContext.new

                start_at = Time.now

                @update_queue.size.times do
                  vnode = @update_queue.dequeue

                  if vnode.component&.dirty?
                    patch_vnode(ctx, vnode, vnode.descriptor)
                  end
                end

                commit!(ctx)
                # puts "\e[34mRendering took %.3fs\e[0m" % (Time.now - start_at)
              end
            rescue => e
              puts e.message
              puts e.backtrace
              error = {
                type: e.class.name,
                message: e.message,
                backtrace: e.backtrace
              }

              @on_update.enqueue([:exception, error])
            end,
            Async::Task
          )
      end

      sig { void }
      def stop! = @update_task.stop
      sig { returns(T::Boolean) }
      def running? = @update_task.running?

      sig { params(descriptor: Descriptor).void }
      def render(descriptor)
        start_at = Time.now
        ctx = UpdateContext.new
        @root = patch(ctx, @root, descriptor)
        commit!(ctx)
        # puts "\e[34mRendering took %.3fs\e[0m" % (Time.now - start_at)
      end

      sig { params(handler_id: String, payload: T.untyped).void }
      def handle_event(handler_id, payload = {})
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
        @on_update.enqueue([:exception, error])
      end

      sig { returns(String) }
      def to_html
        @root&.inspect_tree(exclude_components: true).to_s
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
        @on_update.enqueue([:navigate, path])
      end

      private

      sig { params(ctx: UpdateContext).void }
      def commit!(ctx)
        patches = ctx.patches + ctx.stylesheet_patch
        @on_update.enqueue([:patch, patches]) unless patches.empty?
      end

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
        params(
          ctx: UpdateContext,
          vnode: VNode,
          descriptor: Descriptor
        ).returns(VNode)
      end
      def patch_vnode(ctx, vnode, descriptor)
        unless vnode.descriptor.same?(descriptor)
          raise "Can not patch different types!"
        end

        if component = vnode.component
          if component.should_update?(descriptor.props, component.next_state) ||
               component.dirty?
            vnode.descriptor = descriptor
            prev_props, prev_state = component.props, component.state
            component.props = descriptor.props
            component.state = component.next_state.clone
            descriptors =
              add_comments_between_texts(Array(component.render).compact)

            ctx.enter(vnode) do
              vnode.children =
                update_children(ctx, vnode.children.compact, descriptors)
            end

            update_stylesheet(ctx, component)

            component.did_update(prev_props, prev_state)
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
            # Everything seems to be exactly the same
          end
        end

        update_handlers(vnode.props, descriptor.props)
        update_attributes(ctx, vnode, vnode.props, descriptor.props)

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

      sig { params(ctx: UpdateContext, component: Component::Wrapper).void }
      def update_stylesheet(ctx, component)
        stylesheet = component.stylesheet
        return unless stylesheet.is_a?(Modules::CSS::CSSModule)
        return if @sent_stylesheets.include?(stylesheet.hash)
        puts "Adding stylesheet #{stylesheet.path}"
        ctx.stylesheet(stylesheet.hash)
        @sent_stylesheets.add(stylesheet.hash)
      end

      sig do
        params(
          ctx: UpdateContext,
          descriptor: Descriptor,
          nested: T::Boolean
        ).returns(VNode)
      end
      def init_vnode(ctx, descriptor, nested: false)
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
              init_vnode(ctx, _1, nested: true)
            end
        end

        vnode.component&.mount
        update_handlers({}, vnode.props)

        vnode
      end

      sig do
        params(ctx: UpdateContext, vnode: VNode, patch: T::Boolean).returns(
          NilClass
        )
      end
      def remove_vnode(ctx, vnode, patch: true)
        # puts "\e[31mRemoving vnode #{vnode.id} #{vnode.descriptor.type}\e[0m"

        vnode.component&.unmount
        ctx.remove(vnode) if patch
        vnode.children.map { remove_vnode(ctx, _1, patch: false) }
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
          descriptors: T::Array[Descriptor]
        ).returns(T::Array[VNode])
      end
      def update_children(ctx, vnodes, descriptors)
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
                patch_vnode(ctx, vnode, descriptor)
              else
                init_vnode(ctx, descriptor)
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

        vnodes.each { |vnode| remove_vnode(ctx, vnode) }

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
          .each { |handler| @handlers.delete(handler.id) }

        new_props
          .values_at(*T.unsafe(new_handlers))
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
