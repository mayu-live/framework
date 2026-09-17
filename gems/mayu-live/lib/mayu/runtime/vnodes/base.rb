# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "securerandom"

module Mayu
  module Runtime
    module VNodes
      class Base
        attr_reader :id, :descriptor, :parent, :engine

        def initialize(descriptor, parent:, engine:)
          @descriptor = descriptor
          @parent = parent
          @engine = engine
          @id = SecureRandom.alphanumeric
          @task = nil
          @is_new = true
          @is_inserted = false
          @is_removed = false
        end

        def task = @task || parent_task
        def parent_task = @parent&.task || Async::Task.current
        def metrics = @engine.metrics

        def closest(type)
          if type === self
            self
          else
            @parent&.closest(type)
          end
        end

        def start
        end

        def stop
        end

        def insert
        end

        def remove
        end

        def update(_command_collector, _descriptor = nil)
        end

        def write_html(_out)
        end

        def write_html_with_id_tree(out)
          write_html(out)
          dom_id_tree
        end

        def traverse(&block)
          yield self
        end

        def dom_id
          nil
        end

        def dom_id_tree
          nil
        end

        # The ids of the DOM nodes this vnode contributes to its parent
        # element, without descending into them. Wrappers such as components
        # flat-map their children, so a component rendering an array of
        # elements contributes each of them.
        def dom_ids
          (id = dom_id) ? [id] : []
        end

        def tree_path
          @parent&.tree_path || []
        end

        def register_custom_element(_command_collector)
        end

        def inserted?
          @is_inserted
        end

        def removed?
          @is_removed
        end

        def new?
          @is_new
        end

        def mark_inserted
          @is_new = false
          @is_inserted = true
        end

        def mark_removed
          @is_removed = true
          @is_inserted = false
        end

        def marshal_dump
          [@id, @descriptor, @is_new, @is_inserted, @is_removed]
        end

        def marshal_load(a)
          @id, @descriptor, @is_new, @is_inserted, @is_removed = a
          @parent = nil
          @engine = nil
          @task = nil
        end

        def rehydrate(parent:, engine:, **)
          @parent = parent
          @engine = engine
        end
      end
    end
  end
end
