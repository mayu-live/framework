# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "marshalling"

module Mayu
  module Runtime
    module Descriptors
      Element =
        Data.define(:type, :key, :slot, :children, :props) do
          def self.[](type, *children, key: nil, slot: nil, **props)
            new(type, key, slot, Children[children], props)
          end

          def same?(other)
            if key == other.key && type == other.type
              if type == :input
                # Inputs are considered to be different if their type changes.
                # Is this a good behavior? I think maybe it comes from from Preact.
                props[:type] == other.props[:type]
              else
                true
              end
            else
              false
            end
          end

          def marshal_dump
            [
              Marshalling.dump_value(type),
              key,
              slot,
              children,
              Marshalling.dump_value(props)
            ]
          end

          def marshal_load(a)
            type, key, slot, children, props = a
            initialize(
              type: Marshalling.load_value(type),
              key:,
              slot:,
              children:,
              props: Marshalling.load_value(props)
            )
          end
        end

      Children =
        Data.define(:descriptors, :slots) do
          def self.[](descriptors)
            new(
              descriptors,
              descriptors.group_by do |descriptor|
                (descriptor in Element[slot:]) ? slot : nil
              end
            )
          end

          def to_ary
            descriptors
          end

          def marshal_dump
            [descriptors]
          end

          def marshal_load(a)
            descriptors = a.first || []
            initialize(
              descriptors:,
              slots:
                descriptors.group_by do |descriptor|
                  (descriptor in Element[slot:]) ? slot : nil
                end
            )
          end
        end

      Comment = Data.define(:content) { alias to_s content }
      RawText = Data.define(:content) { alias to_s content }
      Context =
        Data.define(:values, :children) do
          def marshal_dump
            [Marshalling.dump_value(values), children]
          end

          def marshal_load(a)
            values, children = a
            initialize(values: Marshalling.load_value(values), children:)
          end
        end

      Callback =
        Data.define(:component, :method_name) do
          def same?(other) =
            self.class === other && component == other.component &&
              method_name == other.method_name

          # Event listeners are rehydrated from their vnode IDs by VAttributes.
          # Persisting the component object here would retain Klenod's anonymous
          # export class, which cannot cross a Marshal boundary.
          def marshal_dump
            [component.instance_variable_get(:@__vnode_id), method_name]
          end

          def marshal_load(a)
            _component_id, method_name = a
            initialize(component: nil, method_name:)
          end
        end

      Slot = Data.define(:component, :name, :fallback)

      def self.same?(a, b)
        case [a, b]
        in [Element, Element]
          a.same?(b)
        in [^(a), ^(a.class)]
          true
        else
          false
        end
      end

      def self.descriptor_or_string(descriptor)
        case descriptor
        in Element | RawText | Context
          descriptor
        else
          (descriptor && descriptor.to_s) || nil
        end
      end
    end
  end
end
