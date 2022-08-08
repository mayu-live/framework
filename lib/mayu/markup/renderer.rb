# typed: strict

module Mayu
  module Markup
    class Renderer
      extend T::Sig

      sig { returns(Modules::CSS::IdentProxy) }
      def styles = @component.styles
      sig { returns(VDOM::Component::Props) }
      def props = @component.props
      sig { returns(VDOM::Component::State) }
      def state = @component.state

      sig do
        params(component: VDOM::Component::Base).void
      end
      def initialize(component)
        @component = component
        @builder = T.let(Builder.new, Builder)
      end

      sig {returns(String)}
      def id
        puts caller.first(10).grep(/lib\/mayu/)
        "asd"
      end

      sig {returns(T::Array[VDOM::Descriptor])}
      def children = props[:children]
      sig {returns(T.nilable(VDOM::Descriptor))}
      def first_child = children.first

      sig {returns(Builder)}
      def __builder
        @builder
      end

      sig {params(name: Symbol, args: T.untyped, kwargs: T.untyped).returns(VDOM::Component::HandlerRef)}
      def handler(name, *args, **kwargs)
        T.unsafe(@component).handler(name, *args, **kwargs)
      end

      sig do
        params(
          text_or_component:
          T.nilable(T.any(T.untyped, VDOM::Descriptor::ComponentType)),
          component_props: T.untyped,
          block: T.nilable(T.proc.bind(Renderer).void)
        ).returns(DescriptorBuilder)
      end
      def h(text_or_component = nil, **component_props, &block)
        if block
          @builder.h(text_or_component, **component_props) do
            instance_eval(&block)
          end
        else
          @builder.h(text_or_component, **component_props)
        end
      end
    end
  end
end
