# typed: strict

module Mayu
  module Renderer
    class VDOM
      extend T::Sig

      ElementType = T.type_alias { T.any(Symbol, T.class_of(Component)) }
      Props = T.type_alias { T::Hash[Symbol, T.untyped] }
      State = T.type_alias { T::Hash[String, T.untyped] }
      KeyIndexMap = T.type_alias { T::Hash[T.untyped, Integer] }

      class Component
        extend T::Sig

        sig {returns(Props)}
        attr_accessor :props
        sig {returns(State)}
        attr_accessor :state
        sig {returns(State)}
        attr_accessor :next_state

        sig {params(vnode: VNode, props: Props).void}
        def initialize(vnode, props)
          @vnode = vnode
          @props = props
          @state = T.let({}, State)
          @next_state = T.let({}, State)
        end

        sig {params(klass: T.class_of(Class)).returns(T::Boolean)}
        def self.component_class?(klass)
          !!(klass.is_a?(Class) && klass < self)
        end

        # Render

        sig {returns(T.nilable(Descriptor::Children))}
        def render = nil

        # Lifecycle methods

        sig {void}
        def did_mount = nil
        sig {void}
        def will_unmount = nil
        sig {params(next_props: Props, next_state: State).returns(T::Boolean)}
        def should_update?(next_props, next_state) = true
        sig {params(prev_props: Props, prev_state: State).void}
        def did_update?(prev_props, prev_state) = nil
      end

      class Descriptor
        extend T::Sig

        Children = T.type_alias { T::Array[ChildType] }
        ChildType = T.type_alias { T.nilable(Descriptor) }

        TEXT = :TEXT
        COMMENT = :COMMENT

        sig {returns(ElementType)}
        attr_reader :type
        sig {returns(Props)}
        attr_reader :props
        sig {returns(T.untyped)}
        attr_reader :key

        sig {params(type: ElementType, props: Props, children: Descriptor::Children).void}
        def initialize(type, props, children = [])
          @type = type
          @props = T.let(props.merge(
            children: Array(children).map { |child|
              if child.is_a?(Descriptor)
                child
              else
                self.class.new(TEXT, {
                  text_content: child,
                })
              end
            }
          ), Props)

          @key = T.let(@props.delete(:key), T.untyped)
        end

        sig {returns(T::Boolean)}
        def text? = @type == TEXT
        sig {returns(T::Boolean)}
        def text? = @type == COMMENT
      end

      class VNode
        extend T::Sig

        Children = T.type_alias { T::Array[T.nilable(VNode)] }

        sig {returns(Descriptor)}
        attr_reader :descriptor
        sig {returns(ElementType)}
        def type = descriptor.type
        sig {returns(Props)}
        def props = descriptor.props
        sig {returns(T.untyped)}
        def key = descriptor.key
        sig {returns(Children)}
        attr_accessor :children
        sig {returns(DOM::Node)}
        attr_accessor :dom

        sig {returns(T.nilable(Component))}
        attr_reader :component

        sig {returns(T.nilable(DOM::Node))}
        attr_reader :dom

        sig {params(vdom: VDOM, descriptor: Descriptor, dom: T.nilable(DOM::Node)).void}
        def initialize(vdom, descriptor, dom = nil)
          @dom = dom
          @vdom = vdom
          @descriptor = descriptor
          @children = T.let([], Children)
          @component = T.let(nil, T.nilable(Component))
          init_component
        end

        sig {void}
        def init_component
          return if @component

          type = descriptor.type

          if type.is_a?(Class) && type < Component
            @component = type.new(self, props)
          end
        end

        sig {params(descriptor: Descriptor).returns(T::Boolean)}
        def same?(descriptor)
          descriptor.type == type && descriptor.key == key
        end
      end

      sig {params(descriptor: Descriptor).void}
      def initialize(descriptor)
        @dom = T.let(DOM.new, DOM)
        @root = T.let(VNode.new(self, descriptor, @dom.root), T.nilable(VNode))
      end

      sig {params(descriptor: Descriptor).void}
      def render(descriptor)
        @root = patch_vnode(@root, descriptor)
      end

      private

      sig {params(vnode: T.nilable(VNode), descriptor: T.nilable(Descriptor)).void}
      def patch(vnode, descriptor)
        patch_vnode(vnode, descriptor)
      end

      sig {params(vnode: T.nilable(VNode), descriptor: T.nilable(Descriptor)).returns(T.nilable(VNode))}
      def patch_vnode(vnode, descriptor)
        unless descriptor
          return nil
        end

        if vnode&.descriptor == descriptor
          return vnode
        end

        vnode ||= vnode = VNode.new(self, descriptor)

        if descriptor.text?
          unless vnode.descriptor.text?
            return VNode.new(self, descriptor)
          end
        end

        if vnode.same?(descriptor)
          component = vnode.component

          if component && component.should_update?(descriptor.props, component.next_state)
            component.props = descriptor.props
            component.state = component.next_state
            descriptors = component.render
          else
            descriptors = descriptor.props[:children]
          end

          vnode.children = diff_children(vnode, descriptors)

          vnode
        else
        end
      end

      sig {params(vnode: VNode).returns(DOM::Node)}
      def create_dom_node(vnode)
        type = vnode.descriptor.type

        unless type.is_a?(Symbol)
          raise ArgumentError, "Trying to create a DOM-node for type #{type.inspect}"
        end

        if type == Descriptor::TEXT
          node = @dom.create_text_node(vnode.props[:text_content].to_s)
        else
          node = @dom.create_element(type)

          vnode.children.each do |child|
            if child
              node.append_child(create_dom_node(child))
            end
          end
        end

        vnode.dom = node
      end

      sig {params(vnode: VNode, descriptors: Descriptor::Children).returns(VNode::Children)}
      def diff_children(vnode, descriptors)
        parent_dom = T.cast(vnode.dom, DOM::Node)

        result = T.let(Array.new(descriptors.length), VNode::Children)

        old_children = vnode.children
        # Before
        old_start_index = 0
        # New front
        new_start_index = 0
        # Old queen
        old_end_index = old_children.length - 1
        # New post
        new_end_index = descriptors.length - 1
        # Old nodes
        old_start_vnode = T.let(old_children[old_start_index], T.nilable(VNode))
        # Old back node
        old_end_vnode = T.let(old_children[old_end_index], T.nilable(VNode))
        # New front node
        new_start_vnode = descriptors[new_start_index]
        # New back node
        new_end_vnode = descriptors[new_end_index]
        # In the above four cases, it is the structure used in hit processing
        keymap = T.let(nil, T.nilable(KeyIndexMap))
        # Loop through processing nodes
        while (old_start_index <= old_end_index && new_start_index <= new_end_index) do
          # The first is not to judge the first four hits , But to skip what has been added undefined Things marked
          unless old_start_vnode
            old_start_vnode = T.cast(old_children[old_start_index += 1], NilClass)
            next
          end

          unless old_end_vnode
            old_end_vnode = T.cast(old_children[old_end_index -= 1], NilClass)
            next
          end

          unless new_start_vnode
            new_start_vnode = T.cast(descriptors[new_start_index += 1], NilClass)
            next
          end

          unless new_end_vnode
            new_end_vnode = T.cast(descriptors[new_end_index -= 1], NilClass)
            next
          end

          case
          when old_start_vnode.same?(new_start_vnode)
            # New and old
            result[new_start_index] = patch_vnode(old_start_vnode, new_start_vnode)
            old_start_vnode = T.cast(old_children[old_start_index += 1], VNode)
            new_start_vnode = T.cast(descriptors[new_start_index += 1], Descriptor)
          when old_end_vnode.same?(new_end_vnode)
            # New post and old post hit
            result[new_end_index] = patch_vnode(old_end_vnode, new_end_vnode)
            old_end_vnode = T.cast(old_children[old_end_index -= 1], VNode)
            new_end_vnode = T.cast(descriptors[new_end_index -= 1], Descriptor)
          when old_start_vnode.same?(new_end_vnode)
            # New and old hits
            result[new_end_index] = patch_vnode(old_start_vnode, new_end_vnode)
            parent_dom.insert_before(
              T.cast(old_start_vnode.dom, DOM::Node),
              old_end_vnode.dom&.next_sibling
            )
            old_start_vnode = T.cast(old_children[old_start_index += 1], VNode)
            new_end_vnode = T.cast(descriptors[new_end_index -= 1], Descriptor)
          when old_end_vnode.same?(new_start_vnode)
            # New before and old after hit
            result[new_start_index] = patch_vnode(old_end_vnode, new_start_vnode)
            # When the new front and old back hit , At this time, we need to move the node . Move the node pointed by the new node to the front of the old node
            parent_dom.insert_before(
              T.cast(old_end_vnode.dom, DOM::Node),
              old_start_vnode.dom
            )
            old_end_vnode = T.cast(old_children[old_end_index -= 1], VNode)
            new_start_vnode = T.cast(descriptors[new_start_index += 1], Descriptor)
          else
            # None of the four hits hit
            # Make keymap A mapping object , So you don't have to traverse the old object every time .
            keymap ||= build_key_index_map(old_children, old_start_index, old_end_index)
            # Look for the current （new_start_idx） This is in the keymap The position number of the map in
            index = keymap[new_start_vnode.key]

            unless index
              # Judge , If idxInOld yes undefined Indicates that it is a brand new item
              # Added items （ Namely new_start_vnode the ) It's not really DOM node
              new_child_vnode = VNode.new(self, new_start_vnode)
              result[old_start_index] = new_child_vnode
              parent_dom.insert_before(create_dom_node(new_child_vnode), old_start_vnode.dom)
            else
              # If not undefined, Not a new item , But to move
              element_to_move = old_children[index]
              result[new_start_index] = patch_vnode(element_to_move, new_start_vnode)
              # Set this to undefined, It means that I have finished this
              # old_children[index] = nil
              # Move , call insert_before It can also be mobile .
              parent_dom.insert_before(T.cast(element_to_move&.dom, DOM::Node), old_start_vnode.dom)
            end
            # The pointer moves down , Just move the new head
            new_start_vnode = T.cast(descriptors[new_start_index += 1], Descriptor)
          end
        end
        # Go ahead and see if there's any left . The cycle is over start It's better than old Small
        if new_start_index <= new_end_index
          # Traverse the new descriptors, Add to the old ones that haven't been processed
          new_start_index.upto(new_end_index) do |i|
            new_child = descriptors[i]
            old_child = old_children[old_start_index]
            next unless new_child
            next unless old_child
            new_child_vnode = VNode.new(self, new_child)
            result[i] = new_child_vnode
            parent_dom.insert_before(create_dom_node(new_child_vnode), old_child.dom)
          end
        elsif (old_start_index <= old_end_index)
          # Batch deletion oldStart and oldEnd Items between pointers
          old_start_index.upto(old_end_index) do |i|
            old_child = old_children[i]
            next unless old_child
            parent_dom.remove_child(T.cast(old_child.dom, DOM::Node))
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
