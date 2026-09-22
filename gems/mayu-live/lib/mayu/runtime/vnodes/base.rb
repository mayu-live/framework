# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

module Mayu
  module Runtime
    module VNodes
      class Base
        attr_reader :id, :descriptor, :parent, :engine

        def initialize(descriptor, parent:, engine:)
          @descriptor = descriptor
          @parent = parent
          @engine = engine
          @id = @engine.next_vnode_id
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

        # Like #write_html, and appends the IdNode of every DOM node written
        # to `ids`, so the browser can adopt the nodes by id.
        def write_html_with_id_tree(out, ids)
          write_html(out)
          collect_id_tree(ids)
        end

        # Appends the IdNodes of the DOM nodes this vnode contributes to its
        # parent element. Elements pass a fresh array to their children, so
        # the tree comes out nested exactly like the DOM, with no arrays or
        # nils to flatten away afterwards. Vnodes that render nothing, such
        # as heads, append nothing.
        def collect_id_tree(ids)
        end

        # The flat list of IdNodes this vnode contributes. The document
        # overrides this with its single root node.
        def dom_id_tree
          ids = []
          collect_id_tree(ids)
          ids
        end

        def traverse(&block)
          yield self
        end

        def dom_id
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
