# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "descriptors"
require_relative "../custom_element"

module Mayu
  module Runtime
    module H
      def self.[](type, *children, **props)
        type = Mayu::CustomElement.from_klenod(type) || type
        Descriptors::Element[type, *children, **props]
      end

      def self.comment(content)
        Descriptors::Comment[content.to_s]
      end

      def self.callback(component, name)
        Descriptors::Callback[component, name]
      end

      def self.context(**values, &block)
        children = block ? Array(block.call) : []
        Descriptors::Context.new(values, Descriptors::Children[children])
      end

      def self.slot(component, name = nil)
        component.__children.slots.fetch(name) { yield if block_given? }
      end
    end
  end
end
