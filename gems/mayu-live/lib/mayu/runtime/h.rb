# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "descriptors"

module Mayu
  module Runtime
    module H
      def self.[](type, *children, **props)
        type = Descriptors::CustomElement.from_klenod(type) || type
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
