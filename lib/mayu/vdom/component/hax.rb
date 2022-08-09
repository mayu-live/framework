# typed: strict

require_relative "../component"

module Mayu
  module VDOM
    module Component
      module Hax
        class HeadComponent < Component::Base
          sig { override.returns(T.nilable(Descriptor)) }
          def render
            h.create_element(:__mayu_head, [children].flatten.compact, props)
          end
        end

        class BodyComponent < Component::Base
          sig { override.returns(T.nilable(Descriptor)) }
          def render
            h.create_element(:__mayu_body, [children].flatten.compact, **props)
          end
        end

        class AComponent < Component::Base
          handler(:click) do |_event, href|
            navigate(href.to_s)
          end

          sig { override.returns(T.nilable(Descriptor)) }
          def render
            overridden_props =
              if props[:href].to_s.match(/\A[a-z0-9]+:\/\//)
                {rel: "noreferrer"}.merge(props)
              else
                props.merge(on_click: handler(:click, props[:href]))
              end

            h.create_element(:__mayu_a, [children].flatten.compact, overridden_props)
          end
        end
      end
    end
  end
end
