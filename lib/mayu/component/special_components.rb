# typed: strict

module Mayu
  module Component
    module SpecialComponents
      class Head < Component::Base
        sig { override.returns(T.nilable(VDOM::Descriptor)) }
        def render
          h.create_element(:__mayu_head, [children].flatten.compact, props)
        end
      end

      class Body < Component::Base
        sig { override.returns(T.nilable(VDOM::Descriptor)) }
        def render
          h.create_element(:__mayu_body, [children].flatten.compact, **props)
        end
      end

      class A < Component::Base
        class NavigateHandler
          def to_s
            "Mayu.navigate(event)"
          end
        end

        sig { params(_: T.untyped, href: String).void }
        def handle_click(_, href)
          helpers.navigate(href.to_s)
        end

        sig { override.returns(T.nilable(VDOM::Descriptor)) }
        def render
          overridden_props =
            if props[:href].to_s.match(%r{\A[a-z0-9]+://})
              { rel: "noreferrer", **props }
            else
              { **props, on_click: NavigateHandler.new }
            end

          h.create_element(
            :__mayu_a,
            [children].flatten.compact,
            overridden_props
          )
        end
      end
    end
  end
end
