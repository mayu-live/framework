# typed: strict

require_relative "component"
require_relative "descriptor"
require_relative "dom"
require_relative "vnode"

module Mayu
  module VDOM
    class VTree
      extend T::Sig

      KeyIndexMap = T.type_alias { T::Hash[T.untyped, Integer] }

      sig {params(descriptor: Descriptor).void}
      def initialize(descriptor)
        @id_counter = T.let(0, Integer)
        @dom = T.let(DOM.new, DOM)
        @update_queue = T.let([], T::Array[VNode])
        @root = T.let(nil, T.nilable(VNode))
        @handlers = T.let({}, T::Hash[String, Component::HandlerRef])
        render(descriptor)
      end

      sig {returns(T.untyped)}
      def id_tree
        @root&.id_tree
      end

      sig {params(vnode: VNode).void}
      def enqueue_update!(vnode)
        @update_queue.push(vnode)
      end

      sig {params(descriptor: Descriptor).void}
      def render(descriptor)
        @root = patch_vnode(@root, descriptor)
      end

      sig {params(exclude_components: T::Boolean).returns(String)}
      def inspect_tree(exclude_components: false)
        @root&.inspect_tree(exclude_components:).to_s
      end

      sig {params(handler_id: String, payload: T.untyped).void}
      def handle_event(handler_id, payload = {})
        @handlers.fetch(handler_id) {
          raise KeyError, "Handler not found: #{handler_id}"
        }.call(payload)
      end

      sig {returns(Integer)}
      def next_id! = @id_counter += 1

      private

      sig {params(vnode: T.nilable(VNode), descriptor: T.nilable(Descriptor)).returns(T.nilable(VNode))}
      def patch_vnode(vnode, descriptor)
        unless descriptor
          destroy_vnode(vnode) if vnode
          return nil
        end

        unless vnode
          return init_vnode(descriptor)
        end

        if descriptor.text?
          unless vnode.descriptor.text?
            return init_vnode(descriptor)
          end
        end

        if vnode.same?(descriptor)
          component = vnode.component

          if component
            if component.should_update?(descriptor.props, component.next_state) || component.dirty?
              component.props = descriptor.props
              component.state = component.next_state
              descriptors = component.render
            else
              vnode.descriptor = descriptor

              vnode.children = Array(vnode.children).flatten.compact.map do
                patch_vnode(_1, _1.descriptor)
              end

              return vnode
            end
          else
            descriptors = descriptor.props[:children]
            update_handlers(vnode.props, descriptor.props)
          end

          vnode.descriptor = descriptor
          vnode.children = diff_children(vnode, descriptors)

          vnode
        else
          descriptors = descriptor.props[:children]
          vnode.descriptor = descriptor
          vnode.children = diff_children(vnode, descriptors)
          vnode
        end
      end

      sig {params(descriptor: Descriptor).returns(VNode)}
      def init_vnode(descriptor)
        vnode = VNode.new(self, descriptor)

        if component = vnode.init_component
          component.props = descriptor.props
          child_descriptors = component.render
        else
          child_descriptors = descriptor.props[:children]
        end

        update_handlers({}, vnode.props)

        vnode.children = diff_children(
          vnode,
          Array(child_descriptors).flatten.compact
        )

        vnode
      end

      sig {params(vnode: VNode).void}
      def destroy_vnode(vnode)
        update_handlers(vnode.props, {})
        vnode.children.flatten.compact.each { destroy_vnode(vnode) }
      end

      sig {params(old_props: Component::Props, new_props: Component::Props).void}
      def update_handlers(old_props, new_props)
        old_handlers = old_props.keys.select { _1.start_with?("on_") }
        new_handlers = new_props.keys.select { _1.start_with?("on_") }

        removed_handlers = old_handlers - new_handlers

        old_props.values_at(*T.unsafe(removed_handlers)).each do |handler|
          @handlers[handler.id] = handler
        end

        new_props.values_at(*T.unsafe(new_handlers)).each do |handler|
          @handlers[handler.id] = handler
        end
      end

      sig {params(vnode: VNode, descriptors: Descriptor::Children).returns(VNode::Children)}
      def diff_children(vnode, descriptors)
        descriptors = Array(descriptors).flatten.compact
        #parent_dom = T.cast(vnode.dom, DOM::Node)

        result = T.let(Array.new(descriptors.length), VNode::Children)

        old_children = vnode.children
        # Before
        old_start_index = 0
        # New front
        start_descriptor_index = 0
        # Old queen
        old_end_index = old_children.length
        # New post
        end_descriptor_index = descriptors.length
        # In the above four cases, it is the structure used in hit processing
        keymap = T.let(nil, T.nilable(KeyIndexMap))
        # Loop through processing nodes
        while old_start_index <= old_end_index && start_descriptor_index <= end_descriptor_index
          # The first is not to judge the first four hits , But to skip what has been added undefined Things marked
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
            result[start_descriptor_index] = patch_vnode(old_start_vnode, start_descriptor)
            old_start_vnode = old_children[old_start_index += 1]
            if x = descriptors[start_descriptor_index += 1]
              start_descriptor = x
            end
          when old_end_vnode.same?(end_descriptor)
            # New post and old post hit
            result[end_descriptor_index] = patch_vnode(old_end_vnode, end_descriptor)
            old_end_vnode = old_children[old_end_index -= 1]
            end_descriptor = descriptors[end_descriptor_index -= 1]
          when old_start_vnode.same?(end_descriptor)
            # New and old hits
            result[end_descriptor_index] = patch_vnode(old_start_vnode, end_descriptor)
            # parent_dom.insert_before(
            #   T.cast(old_start_vnode.dom, DOM::Node),
            #   old_end_vnode.dom&.next_sibling
            # )
            old_start_vnode = old_children[old_start_index += 1]
            end_descriptor = descriptors[end_descriptor_index -= 1]
          when old_end_vnode.same?(start_descriptor)
            # New before and old after hit
            result[start_descriptor_index] = patch_vnode(old_end_vnode, start_descriptor)
            # When the new front and old back hit , At this time, we need to move the node . Move the node pointed by the new node to the front of the old node
            # parent_dom.insert_before(
            #   T.cast(old_end_vnode.dom, DOM::Node),
            #   old_start_vnode.dom
            # )
            old_end_vnode = old_children[old_end_index -= 1]
            start_descriptor = descriptors[start_descriptor_index += 1]
          else
            # None of the four hits hit
            # Make keymap A mapping object , So you don't have to traverse the old object every time .
            keymap ||= build_key_index_map(old_children, old_start_index, old_end_index)
            # Look for the current （new_start_idx） This is in the keymap The position number of the map in
            index = keymap[start_descriptor.key]

            unless index
              # Judge , If idxInOld yes undefined Indicates that it is a brand new item
              # Added items （ Namely start_descriptor the ) It's not really DOM node
              new_child_vnode = init_vnode(start_descriptor)
              p new_child_vnode.descriptor.text if new_child_vnode.descriptor.text?
              result.insert(start_descriptor_index, new_child_vnode)
              # parent_dom.insert_before(create_dom_node(new_child_vnode), old_start_vnode.dom)
            else
              # If not undefined, Not a new item , But to move
              element_to_move = old_children[index]
              result[start_descriptor_index] = patch_vnode(element_to_move, start_descriptor)
              # Set this to undefined, It means that I have finished this
              # old_children[index] = nil
              # Move , call insert_before It can also be mobile .
              # parent_dom.insert_before(T.cast(element_to_move&.dom, DOM::Node), old_start_vnode.dom)
            end
            # The pointer moves down , Just move the new head
            start_descriptor = descriptors[start_descriptor_index += 1]
          end
        end
        # Go ahead and see if there's any left . The cycle is over start It's better than old Small
        if start_descriptor_index <= end_descriptor_index
          # Traverse the new descriptors, Add to the old ones that haven't been processed
          start_descriptor_index.upto(end_descriptor_index) do |i|
            new_child = descriptors[i]
            old_child = old_children[old_start_index]
            next unless new_child
            new_child_vnode = init_vnode(new_child)
            p new_child_vnode.descriptor.text if new_child_vnode.descriptor.text?
            result.push(new_child_vnode)
            # parent_dom.insert_before(create_dom_node(new_child_vnode), old_child&.dom)
          end
        elsif (old_start_index <= old_end_index)
          # Batch deletion oldStart and oldEnd Items between pointers
          old_start_index.upto(old_end_index) do |i|
            old_child = old_children[i]
            next unless old_child
            # parent_dom.remove_child(T.cast(old_child.dom, DOM::Node))
          end
        end

        result
      end

      sig {params(children: VNode::Children, start_index: Integer, end_index: Integer).returns(KeyIndexMap)}
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
