# typed: strict

module Mayu
  module Component
    module SpecialComponents
      class HeadComponent < Component::Base
        sig { override.returns(T.nilable(VDOM::Descriptor)) }
        def render
          h.create_element(:__mayu_head, [children].flatten.compact, props)
        end
      end

      class BodyComponent < Component::Base
        sig { override.returns(T.nilable(VDOM::Descriptor)) }
        def render
          h.create_element(:__mayu_body, [children].flatten.compact, **props)
        end
      end

      class AComponent < Component::Base
        sig { params(_: T.untyped, href: String) }
        def handle_click(_, href)
          navigate(href.to_s)
        end

        sig { override.returns(T.nilable(VDOM::Descriptor)) }
        def render
          overridden_props =
            if props[:href].to_s.match(%r{\A[a-z0-9]+://})
              { rel: "noreferrer" }.merge(props)
            else
              props.merge(on_click: handler(:handle_click, props[:href]))
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
