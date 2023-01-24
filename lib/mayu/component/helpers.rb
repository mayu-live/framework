# typed: strict

module Mayu
  module Component
    class Helpers
      extend T::Sig

      sig { params(wrapper: Component::Wrapper).void }
      def initialize(wrapper)
        @wrapper = wrapper
      end

      sig do
        params(
          url: String,
          method: Symbol,
          headers: T::Hash[String, String],
          body: T.nilable(String)
        ).returns(Fetch::Response)
      end
      def fetch(url, method: :GET, headers: {}, body: nil)
        vnode.fetch(url, method:, headers:, body:)
      end

      sig { params(path: String).void }
      def navigate(path)
        vnode.navigate(path)
      end

      sig { params(selector: String, options: String).void }
      def scroll_into_view(selector, **options)
        vnode.action(:scroll_into_view, { selector:, options: })
      end

      sig { params(message: String).void }
      def alert(message)
        vnode.action(:alert, message)
      end

      sig { returns(State) }
      def state = @wrapper.state
      sig { returns(Props) }
      def props = @wrapper.props

      sig { returns(VDOM::Children) }
      def children = props[:children]

      sig { params(sources: Props).returns(Props) }
      def merge_props(*sources)
        result = sources.reduce({}, &:merge)

        if result.delete(:class)
          classes = sources.map { _1[:class] }.flatten.compact
          result[:class] = T.unsafe(@wrapper.instance).styles[*classes]
        end

        result
      end

      sig do
        params(
          name: T.nilable(String),
          fallback: T.nilable(T.proc.returns(VDOM::Interfaces::Descriptor))
        ).returns(
          T.nilable(
            T.any(
              VDOM::Interfaces::Descriptor,
              T::Array[VDOM::Interfaces::Descriptor]
            )
          )
        )
      end
      def slot(name = nil, &fallback) = children.slot(name, &fallback)

      sig { returns(T::Array[T.nilable(String)]) }
      def slot_names = children.slots.keys

      sig do
        params(name: Symbol, args: T.untyped, kwargs: T.untyped).returns(
          HandlerRef
        )
      end
      def handler(name, *args, **kwargs)
        HandlerRef.new(@wrapper.instance, name, args, kwargs)
      end

      private

      sig { returns(VDOM::VNode) }
      def vnode = @wrapper.vnode
    end
  end
end
