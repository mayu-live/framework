# typed: strict

require_relative "h"
require_relative "../modules/css"
require_relative "../markup"

require_relative "component/interface"
require_relative "component/base"
require_relative "component/wrapper"
require_relative "component/special_components"

module Mayu
  module VDOM
    module Component
      extend T::Sig

      Props = T.type_alias { T::Hash[Symbol, T.untyped] }
      State = T.type_alias { T::Hash[String, T.untyped] }

      sig do
        params(
          vnode: VNode,
          type: T.untyped,
          props: Props,
          task: Async::Task
        ).returns(T.nilable(Wrapper))
      end
      def self.wrap(vnode, type, props, task: Async::Task.current)
        if type.is_a?(Class) && type < Component::Base
          Wrapper.new(vnode, type, props, task:)
        else
          nil
        end
      end
    end
  end
end
