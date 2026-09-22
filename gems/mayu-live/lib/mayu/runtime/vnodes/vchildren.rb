# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "base"
require_relative "vany"
require_relative "../commands"

module Mayu
  module Runtime
    module VNodes
      class VChildren < Base
        STRING_SEPARATOR = Descriptors::Comment[""]
        UpdateState =
          Data.define(
            :diff_children,
            :removed,
            :children_changed,
            :cursor,
            :new_children
          )

        private def instance_variables_to_inspect = %i[@id @children]

        attr_reader :children

        def initialize(descriptor, parent:, engine:)
          super
          @children = build_children(@descriptor)
        end

        def update(collector, descriptors = nil)
          previous_children = @children
          previous_descriptor = @descriptor
          previous_pending_update = @pending_update
          previous_pending_descriptor = @pending_descriptor
          previous_pending_enqueued = @pending_enqueued
          created_nodes = []

          return unless descriptors || @pending_update

          # Same children object and nothing pending; see VComponent#unchanged?.
          if descriptors&.equal?(@descriptor) && !@pending_update &&
              !@engine&.force_render?
            return
          end

          if @pending_update
            @pending_descriptor = descriptors if descriptors
            @pending_enqueued = false
            update_children(collector, @children, @descriptor, created_nodes)
            return
          end

          if descriptors
            @descriptor = descriptors
            @pending_enqueued = false
          end

          update_children(collector, @children, @descriptor, created_nodes)
        rescue
          # A created vnode may already have been started before a later sibling
          # fails. Its commands are rolled back by the error boundary, so remove
          # it from the server tree as well before restoring the last committed
          # child collection.
          created_nodes.uniq.each { |node| discard_node(node) }
          @children = previous_children
          @descriptor = previous_descriptor
          @pending_update = previous_pending_update
          @pending_descriptor = previous_pending_descriptor
          @pending_enqueued = previous_pending_enqueued
          raise
        end

        def replace(collector, descriptors)
          new_children = build_children(descriptors)
          old_children = @children

          old_children.each { |node| discard_node(node) }
          @descriptor = descriptors
          @children = new_children
          @pending_update = nil
          @pending_descriptor = nil
          @pending_enqueued = false

          new_children.each { |node| insert_node(collector, node) }
          mark_parent_children_dirty
        rescue
          new_children&.each { |node| discard_node(node) }
          raise
        end

        def start
          @children.each(&:start)
        end

        def stop
          @children.each(&:stop)
        end

        def insert
          @children.each(&:insert)
        end

        def remove
          @children.each(&:remove)
        end

        def write_html(out)
          @children.each { |child| child.write_html(out) }
        end

        def write_html_with_id_tree(out, ids)
          @children.each { |child| child.write_html_with_id_tree(out, ids) }
        end

        def collect_id_tree(ids)
          @children.each { |child| child.collect_id_tree(ids) }
        end

        def traverse(&block)
          yield self
          @children.each { |child| child.traverse(&block) }
        end

        def dom_ids
          @children.flat_map(&:dom_ids)
        end

        # The ids of the DOM nodes these children contribute to the closest
        # element, in order. Only the top level is needed: the browser keeps
        # every node by id and replaces the element's children by those ids.
        def dom_id_list
          dom_ids
        end

        def marshal_dump
          [super, @children]
        end

        def marshal_load(a)
          a => [base, children]
          super(base)
          @children = children
        end

        def rehydrate(parent:, engine:, **)
          super
          @children.each do |child|
            child.rehydrate(parent: self, engine: engine, **)
          end
        end

        private

        def build_children(descriptors)
          children = []
          normalize_descriptors(descriptors).each do |descriptor|
            children << VAny.new(descriptor, parent: self, engine: @engine)
          end
          children
        rescue
          children.each { |node| discard_node(node) }
          raise
        end

        def update_children(collector, old_children, descriptors, created_nodes)
          if @pending_update
            state = @pending_update
          else
            diff =
              diff_children(
                old_children,
                normalize_descriptors(descriptors),
                created_nodes
              )
            state =
              UpdateState.new(
                diff[:children],
                diff[:removed],
                diff[:changed],
                0,
                []
              )
          end

          budget_remaining = @engine.update_budget
          cursor = state.cursor

          while cursor < state.diff_children.length
            break if budget_remaining && budget_remaining <= 0

            update = state.diff_children[cursor]
            cursor += 1

            node =
              case update[:type]
              when :updated
                update[:node].update(collector, update[:descriptor])
                update[:node]
              when :created
                node = update[:node]
                insert_node(collector, node)
                node
              end

            state.new_children << node

            budget_remaining -= 1 if budget_remaining
          end

          if cursor < state.diff_children.length
            remaining =
              state
                .diff_children
                .drop(cursor)
                .filter_map do |update|
                  update[:node] if update[:type] == :updated
                end
            @children = state.new_children + remaining
            @pending_update = state.with(cursor:)
            enqueue_resume
            return
          end

          @children = state.new_children

          state.removed.each { |removed| remove_node(collector, removed) }

          mark_parent_children_dirty if state.children_changed

          @pending_update = nil
          @pending_enqueued = false

          if @pending_descriptor
            descriptor = @pending_descriptor
            @pending_descriptor = nil
            @descriptor = descriptor
            update_children(collector, @children, @descriptor, created_nodes)
          end
        end

        def enqueue_resume
          return if @pending_enqueued
          @pending_enqueued = true
          if (element = closest(VElement))
            metrics.update_chunk_count.increment(
              labels: {
                tag_name: element.tag_name
              }
            )
          end
          @engine.enqueue_update(self)
        end

        def diff_children(old_children, descriptors, created_nodes)
          source = old_children.dup
          children_changed = false

          new_children =
            descriptors.map do |descriptor|
              index = source.index do
                @engine.same_descriptor?(descriptor, it.descriptor)
              end
              if index
                children_changed ||= !index.zero?
                found = source.delete_at(index)
                {type: :updated, node: found, descriptor: descriptor}
              else
                children_changed = true
                node = VAny.new(descriptor, parent: self, engine: @engine)
                created_nodes << node
                {type: :created, node:}
              end
            end

          children_changed ||= !source.empty?
          {children: new_children, removed: source, changed: children_changed}
        end

        def insert_node(collector, node)
          node.traverse { |child| child.register_custom_element(collector) }
          node.start if @engine&.task
          node.insert

          html = +""
          ids = []
          node.write_html_with_id_tree(html, ids)

          case ids.length
          when 0
            # Nothing reached the DOM, like a head node.
          else
            collector << Commands::CreateTree[html, ids]
          end
          node.traverse do |child|
            child.emit_listeners(collector) if child.is_a?(VElement)
          end

          node.mark_inserted
          node.traverse do |child|
            child.mark_listeners_dirty if child.is_a?(VElement)
          end
        end

        def remove_node(collector, node)
          node.stop if @engine&.task
          node.remove

          collector << Commands::RemoveNode[node.dom_id] if node.dom_id

          node.traverse { |child| child.mark_removed }
        end

        def discard_node(node)
          node.stop if @engine&.task
          node.remove
          node.traverse { |child| child.mark_removed }
        end

        def normalize_descriptors(descriptors)
          normalized = []
          append_normalized_descriptors(descriptors, normalized)
          normalized
        end

        def mark_parent_children_dirty
          closest(VElement)&.mark_children_dirty
        end

        def append_normalized_descriptors(descriptors, normalized)
          if (nested = Array.try_convert(descriptors))
            nested.each do |descriptor|
              append_normalized_descriptors(descriptor, normalized)
            end
            return
          end

          descriptor = Descriptors.descriptor_or_string(descriptors)
          return unless descriptor

          if descriptor.is_a?(String) && normalized.last.is_a?(String)
            normalized << STRING_SEPARATOR
          end
          normalized << descriptor
        end
      end
    end
  end
end
