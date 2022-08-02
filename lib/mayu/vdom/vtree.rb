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

      sig { params(descriptor: Descriptor, task: Async::Barrier).void }
      def initialize(descriptor, task: Async::Task.current)
        @id_counter = T.let(0, VNode::Id)
        @dom = T.let(DOM.new, DOM)
        @update_queue = T.let(Async::Queue.new, Async::Queue)
        @root = T.let(nil, T.nilable(VNode))
        @handlers = T.let({}, T::Hash[String, Component::HandlerRef])
        @on_update = T.let(Async::Condition.new, Async::Condition)
        @patch_sets = T.let([], T::Array[PatchSet])
        @current_patch_set = T.let(PatchSet.new, PatchSet)

        @update_task =
          T.let(
            task.async(annotation: "VTree updater") do |task|
              loop do
                @update_queue.size.times do
                  vnode = @update_queue.dequeue

                  render_vnode(vnode) if vnode.component&.dirty?
                end

                commit!

                sleep 0.05
              end
            rescue => e
              puts e
            end,
            Async::Task
          )

        render(descriptor)
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

        # puts "\e[33mEnqueueing\e[0m"

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

        if component = vnode.init_component(task: @update_task)
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

        vnode.component&.did_mount

        vnode
      end

      sig { params(vnode: VNode, patch: T::Boolean).void }
      def destroy_vnode(vnode, patch: true)
        vnode.component&.will_unmount

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

        vnode_start_index = 0
        descriptor_start_index = 0
        vnode_end_index = old_children.length.pred
        descriptor_end_index = descriptors.length.pred

        keymap = T.let(nil, T.nilable(KeyIndexMap))

        while vnode_start_index <= vnode_end_index &&
                descriptor_start_index <= descriptor_end_index
          start_vnode = old_children[vnode_start_index]
          vnode_start_index += 1 and next unless start_vnode
          end_vnode = old_children[vnode_end_index]
          vnode_end_index -= 1 and next unless end_vnode

          start_descriptor = descriptors[descriptor_start_index]
          descriptor_start_index += 1 and next unless start_descriptor
          end_descriptor = descriptors[descriptor_end_index]
          descriptor_end_index -= 1 and next unless end_descriptor

          if start_vnode.same?(start_descriptor)
            result[descriptor_start_index] = patch_vnode(
              parent_id,
              start_vnode,
              start_descriptor,
              patch:
            )
            vnode_start_index += 1
            descriptor_start_index += 1
            next
          end

          if end_vnode.same?(end_descriptor)
            result[descriptor_end_index] = patch_vnode(
              parent_id,
              end_vnode,
              end_descriptor,
              patch:
            )
            vnode_end_index -= 1
            descriptor_end_index -= 1
            next
          end

          if start_vnode.same?(end_descriptor)
            result[descriptor_end_index] = patch_vnode(
              parent_id,
              start_vnode,
              end_descriptor,
              patch:
            )
            if patch
              @current_patch_set.move_before(
                parent_id,
                start_vnode.id,
                old_children[vnode_start_index.succ]&.id
              )
            end
            vnode_start_index += 1
            descriptor_end_index -= 1
            next
          end

          if end_vnode.same?(start_descriptor)
            result[descriptor_start_index] = patch_vnode(
              parent_id,
              end_vnode,
              start_descriptor,
              patch:
            )
            if patch
              @current_patch_set.move_before(
                parent_id,
                end_vnode.id,
                start_vnode.id
              )
            end
            vnode_end_index -= 1
            descriptor_start_index += 1
            next
          end

          keymap ||=
            build_key_index_map(
              old_children,
              vnode_start_index,
              vnode_end_index
            )

          if index = keymap[start_descriptor.key]
            vnode_to_move =
              patch_vnode(
                parent_id,
                old_children[index],
                start_descriptor,
                patch:
              )

            old_children[index] = nil

            result[descriptor_start_index] = vnode_to_move

            if patch
              @current_patch_set.move_before(
                parent_id,
                vnode_to_move.id,
                start_vnode.id
              )
            end

            descriptor_start_index += 1
            next
          end

          # https://github.com/vuejs/vue/blob/main/src/core/vdom/patch.ts#L501
          new_vnode = init_vnode(parent_id, start_descriptor, patch: false)
          result.insert(descriptor_start_index, new_vnode)
          # puts "Going to insert #{new_vnode.inspect_tree} "
          if patch
            @current_patch_set.insert_before(
              parent_id,
              new_vnode,
              start_vnode.id
            )
          end

          descriptor_start_index += 1
        end

        # if vnode_start_index > vnode_end_index
        #   #      refElm = descriptors newCh[newEndIdx + 1]) ? null : newCh[newEndIdx + 1].elm
        #   # addVnodes(
        #   #   parentElm,
        #   #   refElm,
        #   #   newCh,
        #   #   newStartIdx,
        #   #   newEndIdx,
        #   #   insertedVnodeQueue
        #   # )
        #   descriptor_start_index.upto(descriptor_end_index) do |i|
        #     new_child = descriptors[i]
        #     old_child = old_children[vnode_start_index]
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
        # elsif descriptor_start_index > descriptor_end_index
        #   p old_children.map { _1 && _1.id }.slice(vnode_start_index..vnode_end_index)
        #   vnode_start_index.upto(vnode_end_index) do |i|
        #     if old_child = old_children[i]
        #       puts "Destroying #{old_child.inspect_tree.scan(/data-mayu-id="\d+"/).join(" ")}"
        #       destroy_vnode(old_child, patch:)
        #     end
        #   end
        # end

        # Go ahead and see if there's any left . The cycle is over start It's better than old Small
        if descriptor_start_index <= descriptor_end_index
          # Traverse the new descriptors, Add to the old ones that haven't been processed
          descriptor_start_index.upto(descriptor_end_index) do |i|
            new_child = descriptors[i]
            old_child = old_children[vnode_start_index]
            next unless new_child
            new_child_vnode = init_vnode(parent_id, new_child, patch: false)
            # p new_child_vnode.descriptor.text if new_child_vnode.descriptor.text?
            # puts "PUSHING THE NEW CHILD #{new_child_vnode.id}"
            result.push(new_child_vnode)
            # parent_dom.insert_before(create_dom_node(new_child_vnode), old_child&.dom)
            if patch
              @current_patch_set.insert_before(
                parent_id,
                new_child_vnode
                # old_child&.id
              )
            end
          end
        end

        new_ids = result.compact.map(&:id)

        old_children.compact.each do |child|
          next if new_ids.include?(child.id)
          # puts "Destroying #{child.inspect_tree.scan(/data-mayu-id="\d+"/).join(" ")}"
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
