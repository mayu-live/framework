# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "base"
require_relative "../dom_nesting_validation"

module Mayu
  module Runtime
    module VNodes
      class VHead < Base
        def initialize(descriptor, parent:, engine:)
          super
          validate_nesting if @engine&.validate_dom_nesting?
          add_to_document
        end

        def children = @descriptor.children

        def title
          Array(children).flatten.find do |child|
            child in Descriptors::Element[type: :title]
          end
        end

        # The children list this head was rendered in. A title template
        # applies to titles in heads anywhere below it.
        def scope = @parent&.parent

        def depth = ancestors.count

        def within?(node) = !node.nil? && ancestors.include?(node)

        # Only a change in content is worth a head flush. A parent that
        # re-renders hands every head node a fresh descriptor, usually with
        # the same title and tags as before.
        def update(_command_collector, descriptor)
          changed = @descriptor != descriptor
          @descriptor = descriptor
          return unless changed

          validate_nesting if @engine&.validate_dom_nesting?
          closest(VDocument)&.mark_head_dirty
        end

        def write_html(_out)
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
        end

        def insert
          add_to_document
        end

        def remove
          remove_from_document
        end

        private

        # The tags inside a head never become elements of their own here, so
        # they are checked against <head> directly.
        def validate_nesting
          head = DOMNestingValidation::AncestorInfo::EMPTY.update(:head)
          path = [*tree_path, {name: "head"}]
          Array(children).flatten.each { validate_descriptor(it, head, path) }
        end

        def validate_descriptor(descriptor, ancestor_info, path)
          return unless descriptor in Descriptors::Element[type: Symbol => tag]

          path = [*path, {name: tag.to_s}]

          if (message, invalid_tag = DOMNestingValidation.check(tag, ancestor_info))
            @engine.warn_dom_nesting(closest(VComponent), message, tree_path: path, invalid_tag:)
          end

          ancestor_info = ancestor_info.update(tag)
          Array(descriptor.children).flatten.each do |child|
            validate_descriptor(child, ancestor_info, path)
          end
        end

        def ancestors
          Enumerator.produce(@parent, &:parent).take_while(&:itself)
        end

        def add_to_document
          closest(VDocument)&.add_head(self)
        end

        def remove_from_document
          closest(VDocument)&.remove_head(self)
        end
      end
    end
  end
end
