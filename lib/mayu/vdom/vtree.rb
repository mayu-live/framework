# typed: strict

require "pry"
require_relative "component"
require_relative "descriptor"
require_relative "dom"
require_relative "vnode"
require_relative "patch_set"
require_relative "../event_emitter"
require "async/queue"

module Mayu
  module VDOM
    class VTree
      extend T::Sig

      KeyIndexMap = T.type_alias { T::Hash[T.untyped, Integer] }

      sig { returns(Async::Condition) }
      attr_reader :on_update

      sig { params(descriptor: Descriptor, task: Async::Task).void }
      def initialize(descriptor, task: Async::Task.new)
        @id_counter = T.let(0, VNode::Id)
        @dom = T.let(DOM.new, DOM)
        @update_queue = T.let(Async::Queue.new, Async::Queue)
        @root = T.let(nil, T.nilable(VNode))
        @handlers = T.let({}, T::Hash[String, Component::HandlerRef])
        @on_update = T.let(Async::Condition.new, Async::Condition)
        @patch_sets = T.let([], T::Array[PatchSet])
        @current_patch_set = T.let(PatchSet.new, PatchSet)
        render(descriptor)

        @update_task =
          T.let(
            task.async do |task|
              loop do
                @update_queue.size.times do
                  vnode = @update_queue.dequeue

                  puts "\e[33mupdatging #{vnode.id}\e[0m"

                  if vnode.component&.dirty?
                    puts "Rendering"

                    render_vnode(vnode)
                  end
                end

                commit!

                task.sleep 0.05
              end
            rescue => e
              puts e
            end,
            Async::Task
          )
      end

      sig { void }
      def stop! = @update_task.stop

      sig { params(descriptor: Descriptor).void }
      def render(descriptor)
        @root = patch_vnode(0, @root, descriptor)
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

        puts "\e[33mEnqueueing\e[0m"

        component.dirty!
        @update_queue.enqueue(vnode)
      end

      sig { void }
      def commit!
        return if @current_patch_set.empty?

        @current_patch_set, patch_set = PatchSet.new, @current_patch_set
        id = @patch_sets.size
        @patch_sets.push(patch_set)
        @on_update.signal([:patch_set, { id:, patch_set: patch_set.to_json }])
      end

      sig { params(exclude_components: T::Boolean).returns(String) }
      def inspect_tree(exclude_components: false)
        @root&.inspect_tree(exclude_components:).to_s
      end

      sig { params(handler_id: String, payload: T.untyped).void }
      def handle_event(handler_id, payload = {})
        @handlers
          .fetch(handler_id) do
            raise KeyError, "Handler not found: #{handler_id}"
          end
          .call(payload)
      end

      sig { returns(VNode::Id) }
      def next_id!
        @id_counter = @id_counter.succ
      end

      private

      sig { params(vnode: VNode).void }
      def render_vnode(vnode)
        # TODO: This doesn't work! Why? Idk.
        vnode.component&.dirty!

        patch_vnode(vnode.parent_id, vnode, vnode.descriptor, patch: true)
      end

      sig do
        params(
          vnode: T.nilable(VNode),
          descriptor: T.nilable(Descriptor)
        ).returns(T.nilable(VNode))
      end
      def patch(vnode, descriptor)
        unless descriptor
          if vnode
            # invoke_destroy_hook(vnode)
            return
          end
        end
      end

      sig do
        params(
          parent_id: VNode::Id,
          vnode: T.nilable(VNode),
          descriptor: T.nilable(Descriptor),
          patch: T::Boolean
        ).returns(T.nilable(VNode))
      end
      def patch_vnode(parent_id, vnode, descriptor, patch: true)
        unless descriptor
          raise "Patching and descriptor is nil"
          destroy_vnode(vnode, patch:) if vnode
          return nil
        end

        return init_vnode(parent_id, descriptor, patch:) unless vnode

        if descriptor.text?
          unless vnode.descriptor.text?
            destroy_vnode(vnode, patch:)
            return init_vnode(parent_id, descriptor, patch:)
          end

          unless descriptor.text == vnode.descriptor.text
            vnode.descriptor = descriptor

            @current_patch_set.update_text(vnode.id, descriptor.text) if patch

            return vnode
          end
        end

        return vnode if descriptor.comment? && vnode.descriptor.comment?

        if vnode.same?(descriptor)
          component = vnode.component

          if component
            if component.should_update?(
                 descriptor.props,
                 component.next_state
               ) || component.dirty?
              component.props = descriptor.props.clone
              component.state = component.next_state.clone
              descriptors = component.render
            else
              vnode.descriptor = descriptor

              vnode.children =
                Array(vnode.children).flatten.compact.map do
                  patch_vnode(parent_id, _1, _1.descriptor, patch:)
                end

              return vnode
            end
          else
            descriptors = descriptor.props[:children]
            parent_id = vnode.id
            update_handlers(vnode.props, descriptor.props)
            update_attributes(vnode.id, vnode.props, descriptor.props) if patch
          end

          vnode.descriptor = descriptor
          vnode.children = diff_children(parent_id, vnode, descriptors, patch:)

          vnode
        else
          destroy_vnode(vnode, patch:)
          init_vnode(parent_id, descriptor, patch:)
        end
      end

      sig do
        params(
          parent_id: VNode::Id,
          descriptor: Descriptor,
          patch: T::Boolean
        ).returns(VNode)
      end
      def init_vnode(parent_id, descriptor, patch: true)
        vnode = VNode.new(self, parent_id, descriptor)

        if component = vnode.init_component
          component.props = descriptor.props
          child_descriptors = component.render
        else
          parent_id = vnode.id
          child_descriptors = descriptor.props[:children]
        end

        update_handlers({}, vnode.props)

        vnode.children =
          diff_children(
            parent_id,
            vnode,
            Array(child_descriptors).flatten.compact,
            patch: false
          )

        vnode
      end

      sig { params(vnode: VNode, patch: T::Boolean).void }
      def destroy_vnode(vnode, patch: true)
        @current_patch_set.remove_node(vnode.id) if patch

        update_handlers(vnode.props, {})

        vnode.children.flatten.compact.each do |child|
          destroy_vnode(child, patch: false)
        end
      end

      sig do
        params(old_props: Component::Props, new_props: Component::Props).void
      end
      def update_handlers(old_props, new_props)
        old_handlers = old_props.keys.select { _1.start_with?("on_") }
        new_handlers = new_props.keys.select { _1.start_with?("on_") }

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
          vnode_id: VNode::Id,
          old_props: Component::Props,
          new_props: Component::Props
        ).void
      end
      def update_attributes(vnode_id, old_props, new_props)
        removed = old_props.keys - new_props.keys - [:children]

        new_props.each do |attr, value|
          next if attr == :children
          next if value == old_props[attr]
          @current_patch_set.set_attribute(vnode_id, attr.to_s, value.to_s)
        end

        removed.each do |attr|
          @current_patch_set.remove_attribute(vnode_id, attr.to_s)
        end
      end

      sig do
        params(
          parent_id: VNode::Id,
          vnode: VNode,
          descriptors: Descriptor::Children,
          patch: T::Boolean
        ).returns(VNode::Children)
      end
      def diff_children(parent_id, vnode, descriptors, patch: true)
        descriptors = Array(descriptors).flatten.compact
        #parent_dom = T.cast(vnode.dom, DOM::Node)

        result = T.let(Array.new(descriptors.length), VNode::Children)

        old_children = vnode.children
        old_start_index = 0
        start_descriptor_index = 0
        old_end_index = old_children.length
        end_descriptor_index = descriptors.length
        keymap = T.let(nil, T.nilable(KeyIndexMap))

        while old_start_index <= old_end_index &&
                start_descriptor_index <= end_descriptor_index
          unless old_start_vnode = old_children[old_start_index]
            old_start_vnode = old_children[old_start_index += 1]
            next
          end

          unless old_end_vnode = old_children[old_end_index]
            old_end_vnode = old_children[old_end_index -= 1]
            next
          end

          unless start_descriptor = descriptors[start_descriptor_index]
            start_descriptor = descriptors[start_descriptor_index += 1]
            next
          end

          unless end_descriptor = descriptors[end_descriptor_index]
            end_descriptor = descriptors[end_descriptor_index -= 1]
            next
          end

          case
          when old_start_vnode.same?(start_descriptor)
            # New and old
            result[start_descriptor_index] = patch_vnode(
              parent_id,
              old_start_vnode,
              start_descriptor,
              patch:
            )
            old_start_vnode = old_children[old_start_index += 1]
            start_descriptor = descriptors[start_descriptor_index += 1]
          when old_end_vnode.same?(end_descriptor)
            # New post and old post hit
            result[end_descriptor_index] = patch_vnode(
              parent_id,
              old_end_vnode,
              end_descriptor,
              patch:
            )
            old_end_vnode = old_children[old_end_index -= 1]
            end_descriptor = descriptors[end_descriptor_index -= 1]
          when old_start_vnode.same?(end_descriptor)
            # New and old hits
            result[end_descriptor_index] = patch_vnode(
              parent_id,
              old_start_vnode,
              end_descriptor,
              patch:
            )
            @current_patch_set.move_node(
              parent_id,
              old_start_vnode.id,
              old_end_vnode.id
            ) if patch
            # parent_dom.insert_before(
            #   T.cast(old_start_vnode.dom, DOM::Node),
            #   old_end_vnode.dom&.next_sibling
            # )
            old_start_vnode = old_children[old_start_index += 1]
            end_descriptor = descriptors[end_descriptor_index -= 1]
          when old_end_vnode.same?(start_descriptor)
            # New before and old after hit
            result[start_descriptor_index] = patch_vnode(
              parent_id,
              old_end_vnode,
              start_descriptor,
              patch:
            )
            # When the new front and old back hit , At this time, we need to move the node . Move the node pointed by the new node to the front of the old node
            # parent_dom.insert_before(
            #   T.cast(old_end_vnode.dom, DOM::Node),
            #   old_start_vnode.dom
            # )
            @current_patch_set.move_node(
              parent_id,
              old_end_vnode.id,
              old_start_vnode.id
            ) if patch
            old_end_vnode = old_children[old_end_index -= 1]
            start_descriptor = descriptors[start_descriptor_index += 1]
          else
            # None of the four hits hit
            # Make keymap A mapping object , So you don't have to traverse the old object every time .
            keymap ||=
              build_key_index_map(old_children, old_start_index, old_end_index)
            # Look for the current （new_start_idx） This is in the keymap The position number of the map in
            index = keymap[start_descriptor.key]

            unless index
              # https://github.com/vuejs/vue/blob/main/src/core/vdom/patch.ts#L501
              new_child_vnode = init_vnode(parent_id, start_descriptor, patch: false)
              result.insert(start_descriptor_index, new_child_vnode)
              @current_patch_set.insert_before(
                parent_id,
                new_child_vnode,
                old_start_vnode.id
              ) if patch
            else
              element_to_move = old_children[index]
              if new_vnode =
                   patch_vnode(parent_id, element_to_move, start_descriptor, patch:)
                result[start_descriptor_index] = new_vnode
                # Set this to undefined, It means that I have finished this
                # old_children[index] = nil
                # Move , call insert_before It can also be mobile .
                # parent_dom.insert_before(T.cast(element_to_move&.dom, DOM::Node), old_start_vnode.dom)
                @current_patch_set.move_node(parent_id, new_vnode.id, old_start_vnode.id) if patch
              end
            end
            # The pointer moves down , Just move the new head
            start_descriptor = descriptors[start_descriptor_index += 1]
          end
        end

        # if old_start_index > old_end_index
        #   #      refElm = descriptors newCh[newEndIdx + 1]) ? null : newCh[newEndIdx + 1].elm
        #   # addVnodes(
        #   #   parentElm,
        #   #   refElm,
        #   #   newCh,
        #   #   newStartIdx,
        #   #   newEndIdx,
        #   #   insertedVnodeQueue
        #   # )
        #   start_descriptor_index.upto(end_descriptor_index) do |i|
        #     new_child = descriptors[i]
        #     old_child = old_children[old_start_index]
        #     next unless new_child
        #     new_child_vnode = init_vnode(parent_id, new_child, patch: false)
        #     # p new_child_vnode.descriptor.text if new_child_vnode.descriptor.text?
        #     result.push(new_child_vnode)
        #     # parent_dom.insert_before(create_dom_node(new_child_vnode), old_child&.dom)
        #     @current_patch_set.insert_before(
        #       parent_id,
        #       new_child_vnode,
        #       old_child&.id
        #     ) if patch
        #   end
        # elsif start_descriptor_index > end_descriptor_index
        #   p old_children.map { _1 && _1.id }.slice(old_start_index..old_end_index)
        #   old_start_index.upto(old_end_index) do |i|
        #     if old_child = old_children[i]
        #       puts "Destroying #{old_child.inspect_tree.scan(/data-mayu-id="\d+"/).join(" ")}"
        #       destroy_vnode(old_child, patch:)
        #     end
        #   end
        # end

        # Go ahead and see if there's any left . The cycle is over start It's better than old Small
        if start_descriptor_index <= end_descriptor_index
          # Traverse the new descriptors, Add to the old ones that haven't been processed
          start_descriptor_index.upto(end_descriptor_index) do |i|
            new_child = descriptors[i]
            old_child = old_children[old_start_index]
            next unless new_child
            new_child_vnode = init_vnode(parent_id, new_child, patch: false)
            # p new_child_vnode.descriptor.text if new_child_vnode.descriptor.text?
            result.push(new_child_vnode)
            # parent_dom.insert_before(create_dom_node(new_child_vnode), old_child&.dom)
            @current_patch_set.insert_before(
              parent_id,
              new_child_vnode,
              old_child&.id
            ) if patch
          end
        # elsif (old_start_index <= old_end_index)
        # elsif start_descriptor_index > end_descriptor_index
        #   # Batch deletion oldStart and oldEnd Items between pointers
        #   old_start_index.upto(old_end_index) do |i|
        #     old_child = old_children[i]
        #     # parent_dom.remove_child(T.cast(old_child.dom, DOM::Node))
        #     destroy_vnode(old_child, patch:) if old_child
        #   end
        end


        new_ids = result.compact.map(&:id)

        old_children.compact.each do |child|
          next if new_ids.include?(child.id)
          puts "Destroying #{child.inspect_tree.scan(/data-mayu-id="\d+"/).join(" ")}"
          destroy_vnode(child, patch:)
        end

        result
      end

      sig do
        params(
          children: VNode::Children,
          start_index: Integer,
          end_index: Integer
        ).returns(KeyIndexMap)
      end
      def build_key_index_map(children, start_index, end_index)
        keymap = {}

        start_index.upto(end_index) do |i|
          key = children[i]&.key
          keymap[key] = i
        end

        keymap
      end
    end
  end
end
