# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

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

        def update(collector, descriptor = nil)
          values_changed = false

          if descriptor
            values_changed = @values != descriptor.values
            @descriptor = descriptor
            @values = @descriptor.values
          end

          with_context do
            if values_changed
              @engine.force_render do
                @children.update(collector, @descriptor.children)
              end
            else
              @children.update(collector, @descriptor.children)
            end
          end
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

        def write_html_with_id_tree(out, ids)
          with_context { @children.write_html_with_id_tree(out, ids) }
        end

        def collect_id_tree(ids)
          @children.collect_id_tree(ids)
        end

        def traverse(&block)
          yield self
          @children.traverse(&block)
        end

        def collect_dom_ids(ids)
          @children.collect_dom_ids(ids)
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
