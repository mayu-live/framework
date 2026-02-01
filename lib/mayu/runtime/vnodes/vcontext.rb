# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "vchildren"
require_relative "vcomponent"

module Mayu
  module Runtime
    module VNodes
      class VContext < Base
        def initialize(descriptor, parent:, engine:)
          super
          @values = @descriptor.values
          @context = @parent.closest(VComponent)&.context
          @children =
            with_context do
              VChildren.new(@descriptor.children, parent: self, engine: @engine)
            end
        end

        def update(patcher, descriptor = nil)
          if descriptor
            @descriptor = descriptor
            @values = @descriptor.values
          end

          with_context { @children.update(patcher, @descriptor.children) }
        end

        def start
          @children.start
        end

        def stop
          @children.stop
        end

        def insert
          @children.insert
        end

        def remove
          @children.remove
        end

        def write_html(out)
          with_context { @children.write_html(out) }
        end

        def traverse(&block)
          yield self
          @children.traverse(&block)
        end

        def dom_id_tree
          @children.dom_id_tree
        end

        def marshal_dump
          [super, @children]
        end

        def marshal_load(a)
          a => [base, children]
          super(base)
          @children = children
          @values = @descriptor.values
          @context = nil
        end

        def rehydrate(parent:, engine:, **)
          super
          @context = @parent.closest(VComponent)&.context
          @children.rehydrate(parent: self, engine: engine, **)
        end

        private

        def with_context
          return yield unless @context
          @context.with(@values) { yield }
        end
      end
    end
  end
end
