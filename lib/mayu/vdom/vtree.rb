# typed: strict

require "async/queue"
require_relative "component"
require_relative "descriptor"
require_relative "dom"
require_relative "vnode"
require_relative "css_attributes"
require_relative "update_context"
require_relative "../event_emitter"

module Mayu
  module VDOM
    class VTree
      extend T::Sig

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

      Id = T.type_alias { Integer }

      sig { returns(T::Array[T.untyped]) }
      attr_reader :patchsets
      sig { returns(Async::Condition) }
      attr_reader :on_update

      sig { params(task: Async::Barrier).void }
      def initialize(task: Async::Task.current)
        @root = T.let(nil, T.nilable(VNode))
        @id_counter = T.let(0, Id)

        @handlers = T.let({}, T::Hash[String, Component::HandlerRef])

        @patchsets = T.let([], T::Array[T.untyped])
        @update_queue = T.let(Async::Queue.new, Async::Queue)
        @on_update = T.let(Async::Condition.new, Async::Condition)

        @update_task =
          T.let(
            task.async(annotation: "VTree updater") do |task|
              loop do
                ctx = UpdateContext.new

                @update_queue.size.times do
                  vnode = @update_queue.dequeue
                  if vnode.component&.dirty?
                    patch_vnode(ctx, vnode, vnode.descriptor)
                  end
                end

                commit!(ctx.patches)

                sleep 0.05
              end
            rescue => e
              puts e
            end,
            Async::Task
          )
      end

      sig {void}
      def stop! = @update_task.stop
      sig {returns(T::Boolean)}
      def running? = @update_task.running?

      sig { params(descriptor: Descriptor).returns(T.nilable(VNode)) }
      def render(descriptor)
        ctx = UpdateContext.new
        @root = patch(ctx, @root, descriptor)
        commit!(ctx.patches)
        @root
      end

      sig { params(handler_id: String, payload: T.untyped).void }
      def handle_event(handler_id, payload = {})
        @handlers
          .fetch(handler_id) do
            raise KeyError, "Handler not found: #{handler_id}"
          end
          .call(payload)
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

      sig { returns(T::Hash[String, String]) }
      def stylesheets
        @root&.stylesheets || {}
      end

      sig { params(vnode: VNode).void }
      def enqueue_update!(vnode)
        component = vnode.component
        return unless component
        return if component.dirty?

        # puts "\e[33mEnqueueing\e[0m"

        component.dirty!
        @update_queue.enqueue(vnode)
      end

      sig { returns(Id) }
      def next_id!
        @id_counter.tap { @id_counter = @id_counter.succ }
      end

      private

      sig { params(patches: T.untyped).void }
      def commit!(patches)
        return if patches.empty?
        id = @patchsets.push(patches).length
        @on_update.signal([:patch, { id:, patches: }])
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
            puts "got here"
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

        children =
          (
            if component
              Array(component.render).compact
            else
              descriptor.props[:children]
            end
          )

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

        old_ch = vnodes
        new_ch = descriptors
        old_start_idx = 0
        new_start_idx = 0
        old_end_idx = old_ch.length.pred
        new_end_idx = new_ch.length.pred

        indexes = Indexes.new(vnodes.map(&:id))
        p indexes.to_a
        moved_ids = Set.new
        children = []

        while old_start_idx <= old_end_idx && new_start_idx <= new_end_idx
          old_start_idx += 1 and next unless old_start_vnode =
            old_ch[old_start_idx]
          old_end_idx -= 1 and next unless old_end_vnode = old_ch[old_end_idx]
          new_start_vnode = T.must(new_ch[new_start_idx])
          new_end_vnode = T.must(new_ch[new_end_idx])

          if new_start_vnode.type == :li
            puts "Order:"
            p indexes.to_a.map { |id|
              old_ch.find { _1.id == id } || children.find { _1.id == id }
            }.map(&:descriptor).map(&:key)
            p [:old_idxes, old_start_idx, old_end_idx]
          end

          # puts "Children order:"
          # p children.sort_by { indexes.index(_1.id) || Float::INFINITY }.map(&:key)

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

          old_key_to_idx =
            build_key_index_map(old_ch, old_start_idx, old_end_idx)

          idx_in_old =
            new_start_vnode.key && old_key_to_idx[new_start_vnode.key]
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
            p [vnode_to_move, new_start_vnode]
            p [old_start_vnode]
            p [old_start_vnode]
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

        children.sort_by! do
          indexes.index(_1.id) or raise "No index found for #{_1.inspect}"
        end

        if old_start_idx > old_end_idx
          # TODO: something about ref elms from the new children
          ref_vnode = children[new_end_idx]

          descriptors_to_add = new_ch.slice(new_start_idx..new_end_idx)

          descriptors_to_add.each do |descriptor|
            p ref_vnode&.id
            new_vnode = init_vnode(ctx, descriptor)
            ctx.insert(new_vnode, before: ref_vnode)
            indexes.insert_before(new_vnode.id, ref_vnode.id)
            children.push(new_vnode)
          end if descriptors_to_add
        elsif new_start_idx > new_end_idx
          vnodes_to_remove = old_ch.slice(old_start_idx..old_end_idx)
          if vnodes_to_remove
            vnodes_to_remove.each do |vnode|
              remove_vnode(ctx, vnode) unless moved_ids.include?(vnode.id)
            end
          end
        end

        children.sort_by do
          indexes.index(_1.id) or raise "No index found for #{_1.inspect}"
        end
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

          if attr == :style && old_value.is_a?(Hash) && value.is_a?(Hash)
            CSSAttributes.new(**old_value).patch(
              ctx,
              vnode,
              CSSAttributes.new(**value)
            )
            next
          end

          ctx.set_attribute(vnode, attr.to_s, value.to_s)
        end

        removed.each { |attr| ctx.remove_attribute(vnode, attr.to_s) }
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
