# typed: strict

module Mayu
  module Component
    module SpecialComponents
      class Head < Component::Base
        sig { override.returns(T.nilable(VDOM::Descriptor)) }
        def render
          VDOM::Descriptor.new(
            :__mayu_head,
            props,
            [children, VDOM.h(:__mayu_links)].flatten.compact
          )
        end
      end

      class Body < Component::Base
        sig { override.returns(T.nilable(VDOM::Descriptor)) }
        def render
          VDOM::Descriptor.new(
            :__mayu_body,
            props,
            [children, VDOM.h(:__mayu_scripts, [], {})].flatten.compact
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
            elsif !props[:href] || props[:href].to_s.empty?
              props
            else
              { **props, on_click: "Mayu.navigate(event)" }
            end

          VDOM::Descriptor.new(
            :__mayu_a,
            overridden_props,
            [children].flatten.compact
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

              VDOM::Descriptor.new(
                descriptor.type,
                {
                  **descriptor.props,
                  key: descriptor.key,
                  selected: !value.nil? && value == descriptor.props[:value]
                },
                descriptor.props[:children]
              )
            end

          VDOM::Descriptor.new(:__mayu_select, props.except(:value), options)
        end
      end
    end
  end
end
