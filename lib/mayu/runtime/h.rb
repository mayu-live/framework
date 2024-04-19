# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "descriptors"

module Mayu
  module Runtime
    module H
      def self.[](type, *children, **props)
        Descriptors::Element[type, *children, **props]
      end

      def self.comment(content)
        Descriptors::Comment[content.to_s]
      end

      def self.callback(component, name)
        Descriptors::Callback[component, name]
      end

      def self.slot(component, name = nil)
        component.__children.slots.fetch(name) { yield if block_given? }
      end

      # H.provide(theme: "dark") do
      # end
      def self.set_context(**vars)
        Descriptors::Context::Provider[vars, yield]
      end
    end
  end
end
