# typed: strict

module Mayu
  module Component
    module SpecialComponents
      class Head < Component::Base
        sig { override.returns(T.nilable(VDOM::Descriptor)) }
        def render
          h.create_element(
            :__mayu_head,
            [children, h.create_element(:__mayu_links, [], {})].flatten.compact,
            **props
          )
        end
      end

      class Body < Component::Base
        sig { override.returns(T.nilable(VDOM::Descriptor)) }
        def render
          h.create_element(
            :__mayu_body,
            [
              children,
              h.create_element(:__mayu_scripts, [], {})
            ].flatten.compact,
            **props
          )
        end
      end

      class A < Component::Base
        EXTERNAL_LINK_RE = T.let(%r{\A[a-z0-9]+://}, Regexp)

        sig { params(_: T.untyped, href: String).void }
        def handle_click(_, href)
          helpers.navigate(href.to_s)
        end

        sig { override.returns(T.nilable(VDOM::Descriptor)) }
        def render
          overridden_props =
            if EXTERNAL_LINK_RE.match?(props[:href] || nil)
              { rel: "noreferrer", external: true, **props }
            else
              { **props, on_click: "Mayu.navigate(event)" }
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
