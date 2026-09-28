# frozen_string_literal: true

module Mayu
  module Test
    module Filters
      Tag =
        Data.define(:name, :text, :attributes) do
          def self.[](tag, text: nil, **attributes)
            new(tag.to_s, text, attributes)
          end

          def match?(node)
            case name
            when "#text"
              return false unless node.text?
            when "#comment"
              return false unless node.comment?
            else
              return false unless node.element?
              return false unless name === node.name
              return false unless attributes.all? do |attr, value|
                value === node[attr.to_s]
              end
            end

            !text || text === node.text
          end

          def to_proc
            ->(node) { match?(node) }
          end
        end
    end
  end
end
