# typed: strict

require_relative "./descriptor"
require_relative "../component"

module Mayu
  module VDOM
    module SpecialElements
      extend T::Sig

      class Head < Component::Base
        sig { override.returns(T.nilable(VDOM::Descriptor)) }
        def render
          T.unsafe(VDOM::H)[
            :__mayu_head,
            *children,
            VDOM::H[:__mayu_links],
            **props
          ]
        end
      end

      class Body < Component::Base
        sig { override.returns(T.nilable(VDOM::Descriptor)) }
        def render
          T.unsafe(VDOM::H)[
            :__mayu_body,
            *children,
            VDOM::H[:__mayu_scripts],
            **props
          ]
        end
      end

      class A < Component::Base
        EXTERNAL_LINK_RE = T.let(%r{\A[a-z0-9]+://}, Regexp)

        sig { override.returns(T.nilable(VDOM::Descriptor)) }
        def render
          T.unsafe(VDOM::H)[:__mayu_a, *children, **overridden_props]
        end

        private

        sig { returns(T::Hash[Symbol, T.untyped]) }
        def overridden_props
          if EXTERNAL_LINK_RE.match?(props[:href] || nil)
            { rel: "noreferrer", external: true, **props }
          elsif !props[:href] || props[:href].to_s.empty?
            props
          else
            { **props, on_click: "Mayu.navigate(event)" }
          end
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

              T.unsafe(VDOM::H)[
                descriptor.type,
                *descriptor.children,
                **descriptor.props,
                key: descriptor.key,
                selected: !value.nil? && value == descriptor.props[:value]
              ]
            end

          T.unsafe(VDOM::H)[:__mayu_select, *options, **props.except(:value)]
        end
      end

      MAPPINGS =
        T.let(
          {
            head: Head,
            __mayu_head: :head,
            body: Body,
            __mayu_body: :body,
            a: A,
            __mayu_a: :a,
            select: Select,
            __mayu_select: :select
          }.freeze,
          T::Hash[Symbol, Component::ElementType]
        )

      sig do
        params(type: Component::ElementType).returns(Component::ElementType)
      end
      def self.for_type(type)
        MAPPINGS.fetch(T.unsafe(type), type)
      end
    end
  end
end
