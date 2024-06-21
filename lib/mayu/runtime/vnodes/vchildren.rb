# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    module VNodes
      class VChildren < Base
        STRING_SEPARATOR = Descriptors::Comment[""]

        Updated = Data.define(:node, :descriptor)
        Created = Data.define(:node)
        UpdateResult = Data.define(:children, :removed)

        attr_reader :children

        def initialize(...)
          super
          update_children([], @descriptor)
        end

        def marshal_dump
          [super, @children]
        end

        def marshal_load(a)
          a => [a, children]
          super(a)
          @children = children
        end

        def traverse(&block)
          yield self
          @children.each { |child| child.traverse(&block) }
        end

        def child_ids
          @children.map(&:child_ids).flatten
        end

        def start_children
          @children.each { |child| Async { child.start } }
        end

        def update_sync(descriptor)
          @descriptor = descriptor
          update_children(@children, @descriptor)
        end

        def insert = @children.map { _1.insert }
        def remove = @children.map { _1.remove }
        def render = @children.map { _1.render }

        private

        def update_children(old_children, descriptors)
          diff = diff_children(old_children, normalize_descriptors(descriptors))

          created = []

          @children =
            diff.children.map do |update|
              case update
              in Updated[node:, descriptor:]
                node.update(descriptor)
                node
              in Created[node:]
                created << node
                node
              end
            end

          if running?
            created.each do |node|
              node.insert
              node.start
            end
          end

          diff.removed.each do |removed|
            removed.remove
            removed.stop
          end

          update_child_ids

          # puts "\e[31m#{diff.removed.map(&:child_ids).join(", ")}\e[0m"
          # puts "\e[33m#{diff.children.select { Updated === _1 }.map(&:node).map(&:child_ids).join(", ")}\e[0m"
          # puts "\e[32m#{diff.children.select { Created === _1 }.map(&:node).map(&:child_ids).join(", ")}\e[0m"
          #

          @children
        end

        def diff_children(old_children, descriptors)
          source = old_children.dup

          new_children =
            descriptors.map do |descriptor|
              if index =
                   source.index { Descriptors.same?(descriptor, _1.descriptor) }
                found = source.delete_at(index)
                Updated[found, descriptor]
              else
                Created[VAny.new(descriptor, parent: self)]
              end
            end

          UpdateResult[new_children, source]
        end

        private

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
