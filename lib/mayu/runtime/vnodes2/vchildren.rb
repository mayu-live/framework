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

        def write_html(out)
          @children.each { |child| child.write_html(out) }
        end

        def dom_id_tree
          @children.map(&:dom_id_tree)
        end

        private

        def build_children(descriptors)
          normalize_descriptors(descriptors).map do |descriptor|
            VAny.new(descriptor, parent: self, engine: @engine)
          end
        end

        def update_children(patcher, old_children, descriptors)
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
          return unless node.respond_to?(:write_html)
          return unless node.respond_to?(:dom_id_tree)

          html = +""
          node.write_html(html)
          patcher << Patches::CreateTree[html, node.dom_id_tree]
          node.mark_inserted if node.respond_to?(:mark_inserted)
        end

        def remove_node(patcher, node)
          return unless node.respond_to?(:dom_id)
          return unless node.dom_id

          patcher << Patches::RemoveNode[node.dom_id]
          node.mark_removed if node.respond_to?(:mark_removed)
        end

        def normalize_descriptors(descriptors)
          Array(descriptors)
            .flatten
            .map { Descriptors.descriptor_or_string(_1) }
            .compact
            .then { insert_comments_between_strings(_1) }
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
