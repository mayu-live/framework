# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "vany"
require_relative "../patches"

module Mayu
  module Runtime
    module VNodes2
      class VChildren < Base
        STRING_SEPARATOR = Descriptors::Comment[""]

        private def instance_variables_to_inspect = %i[@id @children]

        attr_reader :children

        def initialize(descriptor, parent:, engine:)
          super
          @children = build_children(@descriptor)
        end

        def update(patcher, descriptors = nil)
          return unless descriptors
          @descriptor = descriptors
          update_children(patcher, @children, descriptors)
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

        def traverse(&block)
          yield self
          @children.each { |child| child.traverse(&block) }
        end

        def dom_id_tree
          @children.map(&:dom_id_tree)
        end

        def dom_id_list
          dom_id_list_for(@children)
        end

        def dom_id_trees
          @children.map(&:dom_id_tree)
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
          normalize_descriptors(descriptors).map do |descriptor|
            VAny.new(descriptor, parent: self, engine: @engine)
          end
        end

        def update_children(patcher, old_children, descriptors)
          previous_ids = dom_id_list_for(old_children)
          diff = diff_children(old_children, normalize_descriptors(descriptors))

          @children =
            diff[:children].map do |update|
              case update[:type]
              when :updated
                update[:node].update(patcher, update[:descriptor])
                update[:node]
              when :created
                node = update[:node]
                insert_node(patcher, node)
                node
              end
            end

          diff[:removed].each { |removed| remove_node(patcher, removed) }

          mark_parent_children_dirty if previous_ids != dom_id_list
        end

        def diff_children(old_children, descriptors)
          source = old_children.dup

          new_children =
            descriptors.map do |descriptor|
              if index =
                   source.index { Descriptors.same?(descriptor, _1.descriptor) }
                found = source.delete_at(index)
                { type: :updated, node: found, descriptor: descriptor }
              else
                {
                  type: :created,
                  node: VAny.new(descriptor, parent: self, engine: @engine)
                }
              end
            end

          { children: new_children, removed: source }
        end

        def insert_node(patcher, node)
          node.start if @engine&.task
          node.insert if node.respond_to?(:insert)

          if node.respond_to?(:write_html) && node.respond_to?(:dom_id_tree)
            id_tree = node.dom_id_tree
            if id_tree.is_a?(Array)
              id_tree = id_tree.flatten.compact
              if id_tree.length == 1
                id_tree = id_tree.first
              else
                raise "CreateTree expects a single IdNode, got #{id_tree.length}"
              end
            end
            if id_tree
              html = +""
              node.write_html(html)
              patcher << Patches::CreateTree[html, id_tree]
            end
          end

          node.mark_inserted if node.respond_to?(:mark_inserted)
        end

        def remove_node(patcher, node)
          node.stop # if @engine&.task
          node.remove if node.respond_to?(:remove)

          if node.respond_to?(:dom_id) && node.dom_id
            patcher << Patches::RemoveNode[node.dom_id]
          end

          node.mark_removed if node.respond_to?(:mark_removed)
        end

        def normalize_descriptors(descriptors)
          Array(descriptors)
            .flatten
            .map { Descriptors.descriptor_or_string(_1) }
            .compact
            .then { insert_comments_between_strings(_1) }
        end

        def mark_parent_children_dirty
          closest(VElement)&.mark_children_dirty
        end

        def dom_id_list_for(children)
          children.flat_map { |child| dom_id_list_from_tree(child.dom_id_tree) }
        end

        def dom_id_list_from_tree(tree)
          case tree
          when Array
            tree.flat_map { |node| dom_id_list_from_tree(node) }
          when DOM::IdNode
            [tree.id]
          else
            []
          end
        end

        def insert_comments_between_strings(descriptors)
          [nil, *descriptors].each_cons(2)
            .map do |prev, descriptor|
              case [prev, descriptor]
              in [String, String]
                [STRING_SEPARATOR, descriptor]
              else
                descriptor
              end
            end
            .flatten
        end
      end
    end
  end
end
