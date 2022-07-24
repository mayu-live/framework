# typed: strict

require "cgi"
require_relative "types"

module Mayu
  module Renderer
    class VDOM
      extend T::Sig

      class ComponentCommon < T::Struct
        extend T::Sig

        prop :vnode, T.nilable(VNode)
        prop :base, T.nilable(DOM::Node)
        prop :parent_dom, T.nilable(DOM::Node)
        prop :dirty, T::Boolean, default: false
        prop :force, T::Boolean, default: false

        sig {returns(T::Boolean)}
        def dirty? = dirty
        sig {returns(TrueClass)}
        def dirty! = self.dirty = true

        sig {returns(T::Boolean)}
        def force? = force
        sig {returns(TrueClass)}
        def force! = self.force = true

        sig {returns(ComponentCommon)}
        def copy
          self.class.new(
            vnode:,
            base:,
            parent_dom:,
            dirty:,
            force:,
          )
        end
      end

      class ClassComponent < T::Struct
        extend T::Sig

        prop :common, ComponentCommon
        prop :instance, T.nilable(Component)
        prop :props, Types::Props
        prop :state, Types::State, default: {}
        prop :next_state, Types::State, default: {}
        prop :render_callbacks, T::Array[T.proc.void], default: []

        sig {returns(ClassComponent)}
        def copy
          self.class.new(
            common: common.copy,
            instance:,
            props:,
            state:,
            next_state:,
            render_callbacks:,
          )
        end

        sig {params(vnode: VNode, props: Types::Props).returns(T.attached_class)}
        def self.init(vnode, props)
          c = new(
            common: ComponentCommon.new(
              vnode:,
            ),
            props:
          )
          new_type = vnode.type

          raise unless new_type.is_a?(Class)

          c.instance = new_type.new(c)
          c
        end

        sig {returns(Types::ComponentChild)}
        def render
          instance&.render
        end

        sig do
          params(
            update: T.nilable(Types::State),
            blk: T.nilable(T.proc.params(arg0: Types::State, arg1: Types::Props).returns(Types::State))
          ).void
        end
        def set_state(update = nil, &blk)
          s = @next_state == @state ? Utils.deep_dup(@state) : @next_state

          if block_given?
            update = yield Utils.deep_dup(@state), @props
          end

          s.merge!(update) if update

          return unless update # Skip update if updater callback returned null

          if common.vnode
            common.vnode&.vdom.enqueue_render(self)
          end
        end
      end

      class Component
        extend T::Sig

        sig {params(blk: T.proc.void).void}
        def self.component_will_mount(&blk)
          define_method :component_will_mount, &blk
        end
        sig {params(blk: T.proc.void).void}
        def self.component_did_mount(&blk)
          define_method :component_did_mount, &blk
        end
        sig {params(blk: T.proc.void).void}
        def self.component_will_unmount(&blk)
          define_method :component_will_unmount, &blk
        end

        sig {params(wrapper: ClassComponent).void}
        def initialize(wrapper)
          @__wrapper = wrapper
        end

        sig {returns(Types::ComponentChild)}
        def render
          nil
        end

        sig {returns(Types::Props)}
        def props
          @__wrapper.props
        end

        sig {params(next_props: Types::Props, next_state: Types::State).returns(Types::State)}
        def self.get_derived_state_from_props(next_props, next_state)
          {}
        end

        sig {void}
        def component_will_mount = nil
        sig {void}
        def component_did_mount = nil
        sig {void}
        def component_will_unmount = nil

        sig {params(next_props: Types::Props, next_context: T.untyped).void}
        def component_will_receive_props(next_props, next_context = nil)
        end

        sig do
          params(
            next_props: Types::Props,
            next_state: Types::State,
            next_context: T.untyped
          ).returns(T::Boolean)
        end
        def should_component_update?(next_props, next_state, next_context = nil)
          true
        end

        sig do
          params(
            next_props: Types::Props,
            next_state: Types::State,
            next_context: T.untyped
          ).returns(T::Boolean)
        end
        def component_will_update(next_props, next_state, next_context = nil)
          false
        end

        sig do
          params(
            old_props: Types::Props,
            old_state: Types::State,
          ).returns(T.untyped)
        end
        def get_snapshot_before_update(old_props, old_state)
        end

        sig do
          params(
            prev_props: Types::Props,
            prev_state: Types::State,
            prev_context: T.untyped
          ).returns(T::Boolean)
        end
        def component_did_update(prev_props, prev_state, prev_context = nil)
          false
        end

        sig {params(error: StandardError).void}
        def component_did_catch(error)
        end
      end

=begin
      class FunctionComponent < T::Struct
        prop :common, ComponentCommon
        prop :proc,
          T.any(
            T.proc.params(kwargs: Types::Props).returns(Types::ComponentChild),
            T.proc.returns(Types::ComponentChild)
          )
      end

      AnyComponent = T.type_alias { T.any(FunctionComponent, ClassComponent) }
      ComponentType = T.type_alias { T.any(T.class_of(FunctionComponent), T.class_of(ClassComponent)) }
=end

      class VNodeasd < T::Struct
        extend T::Sig
        extend T::Generic

        prop :vdom, VDOM
        prop :type, T.any(Symbol, T.class_of(Component))
        prop :props, Types::Props, default: {}
        prop :children, T::Array[Types::ComponentChild], default: []
        prop :key, T.untyped, default: nil
        prop :parent, T.nilable(VNode)
        prop :depth, Integer, default: 0
        prop :dom, T.nilable(Mayu::Renderer::DOM::Node)
        prop :component, T.nilable(ClassComponent)
        prop :original, Integer, default: 0

        sig {returns(self)}
        def copy
          self.class.new(
            vdom:,
            type:,
            props:,
            children:,
            parent:,
            depth:,
            dom:,
            original:,
            component: component&.copy,
          )
        end
      end

      sig {void}
      def initialize
        @process = T.let([], T::Array[ClassComponent])
        @rerender_queue = T.let([], T::Array[ClassComponent])
        @rerender_count = T.let(0, Integer)
      end

      sig {params(component: ClassComponent).void}
      def enqueue_render(component)
        component.dirty!
        @rerender_queue.push(component)
      end

      sig {void}
      def process_rerender_queue
        while (@rerender_count = @rerender_queue.length).nonzero?
          queue = @rerender_queue.sort_by { _1._vnode.depth.to_i }
          @rerender_queue = []

          queue.each { _1.dirty? && render_component(_1) }
        end
      end

      sig {params(component: AnyComponent).void}
      def render_component(component)
        parent_dom = component.common.parent_dom
        vnode = component.common.vnode
        old_dom = vnode&.dom

        raise unless vnode
        return unless parent_dom

        commit_queue = []

        old_vnode = vnode.copy

        diff(
          parent_dom,
          vnode,
          vnode,
          [old_dom].compact,
          commit_queue,
          T.cast(old_dom ? old_dom : get_dom_sibling(vnode), DOM::Node),
        )

        commit_root(commit_queue)

        unless vnode.dom == old_dom
          update_parent_dom_pointers(vnode)
        end
      end

      AnyComponent = T.type_alias { ClassComponent }

      sig {params(commit_queue: T::Array[AnyComponent]).void}
      def commit_root(commit_queue)
        commit_queue.each do |component|
          # Call and restore all render callbacks
        end
      end

      sig do
        params(
          parent_dom: DOM::Node,
          new_vnode: VNode,
          old_vnode: VNode,
          excess_dom_children: T::Array[DOM::Node],
          commit_queue: T::Array[AnyComponent],
          old_dom: DOM::Node
        ).void
      end
      def diff(
        parent_dom,
        new_vnode,
        old_vnode,
        excess_dom_children,
        commit_queue,
        old_dom
      )
        new_type = new_vnode.type

        catch :outer do
          unless new_type.is_a?(Symbol)
            new_props = new_vnode.props
            is_new = false

            if old_vnode.component
              c = new_vnode.component = old_vnode.component
            else
              case new_type
              when Class
                new_vnode.component = c = ClassComponent.init(new_vnode, new_props)
              # when Proc
                # TODO: This is where we would handle lambda components
              else
                T.absurd(new_type)
              end

              c.props = new_props
              is_new = c.common.dirty!
            end

            raise unless c

            unless new_type.method(:get_derived_state_from_props).owner == Component
              if c.next_state == c.state
                c.next_state = Utils.deep_dup(c.next_state)

                c.next_state.merge!(new_type.get_derived_state_from_props(new_props, c.next_state))
              end

              old_props = c.props
              old_state = c.state

              if is_new
                c.render_callbacks.push(lambda { c.instance&.component_did_mount() })
              else
                if (
                  !c.common.force? &&
                  c.instance&.should_component_update?(new_props, c.next_state, {}) == false
                ) || new_vnode.original === old_vnode.original
                  c.props = new_props
                  c.state = c.next_state

                  unless new_vnode.original == old_vnode.original
                    c.common.dirty = false
                  end

                  c.common.vnode = new_vnode
                  new_vnode.dom = old_vnode.dom
                  new_vnode.children = old_vnode.children
                  new_vnode.children.each { |child| child.parent = new_vnode }

                  unless c.render_callbacks.empty?
                    commit_queue.push(c)
                  end

                  throw :outer
                end

                c.render_callbacks.push(lambda { c.instance&.component_did_update(old_props, old_state, {}) })
              end

              c.props = new_props
              c.common.vnode = new_vnode
              c.common.parent_dom = parent_dom

              c.state = c.next_state
              c.common.dirty = false
              render_result = c.render

              c.state = c.next_state # handle set_state in render

              # TODO: Here we should assign the child context to global context.

              diff_children(
                parent_dom,
                Array(render_result),
                new_vnode,
                old_vnode,
                excess_dom_children,
                commit_queue,
                old_dom,
              )

              c.common.base = new_vnode.dom

              unless c.render_callbacks.empty?
                commit_queue.push(c)
              end

              c.common.force = false
            end
          end
        end
      end

      sig do
        params(
          parent_dom: DOM::Node,
          render_result: T::Array[Types::ComponentChild],
          new_parent_vnode: VNode,
          old_parent_vnode: T.nilable(VNode),
          excess_dom_children: T::Array[DOM::Node],
          commit_queue: T::Array[ClassComponent],
          old_dom: DOM::Node,
        ).void
      end
      def diff_children(
        parent_dom,
        render_result,
        new_parent_vnode,
        old_parent_vnode,
        excess_dom_children,
        commit_queue,
        old_dom
      )
        old_children = old_parent_vnode&.children || []
        old_children_length = old_children.length
        new_parent_vnode.children = []

        render_result.each_with_index do |child_vnode,i|
          if child_vnode.nil? || child_vnode.is_a?(Boolean)
            child_vnode = new_parent_vnode.children[i] = nil
          elsif child_vnode.is_a?(Array)
            child_vnode = new_parent_vnode.children[i] = VNode.new(
              vdom: self,
              type: :ins,
              props: { children: child_vnode },
              key: nil,
            )
          elsif child_vnode.is_a?(String) || child_vnode.is_a?(Numeric)
            child_vnode = new_parent_vnode.children[i] = VNode.new(
              vdom: self,
              type: :TEXT_ELEMENT,
              props: { content: child_vnode.to_s },
            )
          elsif child_vnode.depth > 0
            child_vnode = new_parent_vnode.children[i] = VNode.new(
              vdom: self,
              type: child_vnode.type,
              props: child_vnode.props,
              key: child_vnode.key,
              original: child_vnode.original
            )
          else
            child_vnode = new_parent_vnode.children[i] = child_vnode
          end

          next unless child_vnode

          child_vnode.parent = new_parent_vnode
          child_vnode.depth = new_parent_vnode.depth.succ
          old_vnode = old_children[i]

        if old_vnode.nil? || (old_vnode && child_vnode.key == old_vnode.key && child_vnode.type == old_vnode.type)
          old_children[i] = nil
        else
          old_children_length.times do |j|
            old_vnode = old_children[j]
            if old_vnode && child_vnode.key == old_vnode.key && child_vnode.type == old_vnode.type
              old_children[j] = nil
              break
            end

            old_vnode = nil
          end
        end

        old_vnode ||= {}
      end

      sig {params(vnode: VNode).void}
      def update_parent_dom_pointers(vnode)
        parent = vnode.parent
        return unless parent

        component = parent.component
        return unless component

        parent.dom = component.common.base = nil

        parent.children.each do |child|
          if child.dom
            parent.dom = component.common.base = child.dom
            break
          end
        end

        update_parent_dom_pointers(parent)
      end

      sig {params(vnode: VNode, child_index: T.nilable(Integer)).returns(T.nilable(DOM::Node))}
      def get_dom_sibling(vnode, child_index = 0)
        if child_index.nil?
          if parent = vnode.parent
            return get_dom_sibling(parent, parent.children.index(vnode).to_i + 1)
          else
            return
          end
        end

        while child_index < vnode.children.length
          sibling = vnode.children[child_index]

          return sibling.dom if sibling && sibling.dom

          child_index += 1
        end

        nil
      end
    end
  end
end
