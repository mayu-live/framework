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
        # Components below read these through VComponent::Context.
        attr_reader :values

        def initialize(descriptor, parent:, engine:)
          super
          @values = @descriptor.values
          @children = VChildren.new(@descriptor.children, parent: self, engine: @engine)
        end

        def update(collector, descriptor = nil)
          values_changed = false

          if descriptor
            values_changed = @values != descriptor.values
            @descriptor = descriptor
            @values = @descriptor.values
          end

          if values_changed
            @engine.force_render do
              @children.update(collector, @descriptor.children)
            end
          else
            @children.update(collector, @descriptor.children)
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
          @children.write_html(out)
        end

        def write_html_with_id_tree(out, ids)
          @children.write_html_with_id_tree(out, ids)
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
        end

        def rehydrate(parent:, engine:, **)
          super
          @children.rehydrate(parent: self, engine: engine, **)
        end
      end
    end
  end
end
