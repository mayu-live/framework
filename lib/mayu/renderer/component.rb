# typed: strict

require_relative "../utils"
require_relative "types"

module Mayu
  module Renderer
    class Component2
      extend T::Sig

      sig {params(vdom: Mayu::Renderer::VDOM, props: Types::Props, context: Types::Context).void}
      def initialize(vdom, props, context)
        @vdom = vdom
        @props = props
        @context = context
        @state = T.let({}, Types::State)
        @next_state = T.let({}, Types::State)
        @vnode = T.let(nil, T.nilable(Mayu::Renderer::VDOM::VNode))
        @dirty = T.let(false, T::Boolean)
        @force = T.let(false, T::Boolean)
      end

      sig {returns(VDOM::VNode)}
      def _vnode = T.cast(@vnode, VDOM::VNode)

      sig {returns(Types::ComponentChild)}
      def render
      end


      sig {returns(T::Boolean)}
      def dirty? = @dirty

      sig {returns(TrueClass)}
      def dirty! = @dirty = true

      sig {void}
      def force_update!
        @force = true
        @vdom.enqueue_render(self)
      end

      sig {params(props: Types::Props, state: Types::State).returns(Types::State)}
      def get_derived_state_from_props(props, state)
        {}
      end
    end
  end
end
