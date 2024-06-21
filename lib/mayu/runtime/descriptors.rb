# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

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
        end

      Comment = Data.define(:content) { alias to_s content }

      Callback =
        Data.define(:component, :method_name) do
          def same?(other) =
            self.class === other && component == other.component &&
              method_name == other.method_name
        end

      Slot = Data.define(:component, :name, :fallback)

      module Context
        Provider =
          Data.define(:children, :variables) do
            def self.[](*children, **variables)
              new(children, variables)
            end
          end
      end

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
        if descriptor in Element
          descriptor
        else
          (descriptor && descriptor.to_s) || nil
        end
      end
    end
  end
end
