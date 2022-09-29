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

      class Select < Component::Base
        class InvalidNestingError < StandardError
        end

        sig { override.returns(T.nilable(VDOM::Descriptor)) }
        def render
          value = props[:value]

          options =
            Array(children).flatten.compact.map do |descriptor|
              unless descriptor.type == :option
                raise InvalidNestingError,
                      "Only option are valid children for select, you passed #{descriptor.type}"
              end

              h.create_element(
                descriptor.type,
                descriptor.props[:children],
                {
                  **descriptor.props,
                  key: descriptor.key,
                  selected: !value.nil? && value == descriptor.props[:value]
                }
              )
            end

          h.create_element(:__mayu_select, options, props.except(:value))
        end
      end
    end
  end
end
