# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "velement"
require_relative "../../custom_element"
require_relative "../patches"

module Mayu
  module Runtime
    module VNodes
      class VCustomElement < Base
        def initialize(descriptor, parent:, engine:)
          super
          custom_element = @descriptor.type
          descriptor = @descriptor.with(type: custom_element.name)
          @element = VElement.new(descriptor, parent: self, engine: @engine)
          @engine.add_custom_element(custom_element)
        end

        def update(patcher, descriptor = nil)
          return unless descriptor
          @descriptor = descriptor
          @element.update(
            patcher,
            @descriptor.with(type: @descriptor.type.name)
          )
        end

        def register_custom_element(patcher)
          custom_element = @descriptor.type
          patcher << Patches::RegisterCustomElement[
            custom_element.name,
            custom_element.path
          ]
        end

        def start
          @element.start
        end

        def stop
          @element.stop
        end

        def insert
          @element.insert
        end

        def remove
          @element.remove
        end

        def write_html(out)
          @element.write_html(out)
        end

        def write_html_with_id_tree(out)
          @element.write_html_with_id_tree(out)
        end

        def dom_id
          @element.dom_id
        end

        def dom_id_tree
          @element.dom_id_tree
        end

        def traverse(&block)
          yield self
          @element.traverse(&block)
        end

        def marshal_dump
          [super, @element]
        end

        def marshal_load(a)
          a => [base, element]
          super(base)
          @element = element
        end

        def rehydrate(parent:, engine:, **)
          super
          @element.rehydrate(parent: self, engine: engine, **)
        end
      end
    end
  end
end
