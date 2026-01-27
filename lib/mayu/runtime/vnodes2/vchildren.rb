# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "vany"

module Mayu
  module Runtime
    module VNodes2
      class VChildren < Base
        STRING_SEPARATOR = Descriptors::Comment[""]

        attr_reader :children

        def initialize(descriptor, parent:, engine:)
          super
          @children = build_children(@descriptor)
        end

        def update(_patcher)
        end

        def write_html(_out)
        end

        private

        def build_children(descriptors)
          normalize_descriptors(descriptors).map do |descriptor|
            VAny.new(descriptor, parent: self, engine: @engine)
          end
        end

        def normalize_descriptors(descriptors)
          Array(descriptors)
            .flatten
            .map { Descriptors.descriptor_or_string(_1) }
            .compact
            .then { insert_comments_between_strings(_1) }
        end

        def insert_comments_between_strings(descriptors)
          [nil, *descriptors].each_cons(2)
            .map do |prev, descriptor|
              case [prev, descriptor]
              in [String, String]
                [STRING_SEPARATOR, descriptor]
              else
                descriptor
              end
            end
            .flatten
        end
      end
    end
  end
end
