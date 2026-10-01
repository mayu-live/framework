# frozen_string_literal: true

require "console/event/generic"

require_relative "dom_nesting_warning_formatter"
require_relative "render_error_event"
require_relative "state_update_warning_event"

module Mayu
  module Runtime
    # Logged in development when a component renders elements that the
    # browser would move or rewrite, like a <span> inside a <title>.
    class DOMNestingWarningEvent < Console::Event::Generic
      TYPE = :"mayu.invalid_dom_nesting"

      # `component` is the {name:, path:} node from VComponent#tree_path.
      # `tree_path` leads from the document to the misplaced element, shown
      # the same way as for render errors. The misplaced element and the
      # closest `invalid_tag` element above it are marked as invalid.
      def self.for(component, message:, tree_path: [], invalid_tag: nil, provider: nil)
        tree_path = tree_path.map { RenderErrorEvent.tree_node(it, provider) }
        mark_invalid(tree_path, invalid_tag)

        new(location: location_for(component, provider), message:, tree_path:)
      end

      def self.mark_invalid(tree_path, invalid_tag)
        *ancestors, element = tree_path
        return unless element

        element[:invalid] = true
        ancestor = ancestors.rfind do |node|
          !node[:component] && node[:name] == invalid_tag.to_s
        end
        ancestor[:invalid] = true if ancestor
      end

      def self.location_for(component, provider)
        return "(document)" unless component

        path = component[:path]
        module_id = provider.module_id_for(path) if
          path && provider.respond_to?(:module_id_for)
        module_id || StateUpdateWarningEvent.app_module_id(path) || component[:name]
      rescue KeyError, ArgumentError
        StateUpdateWarningEvent.app_module_id(path) || component[:name]
      end

      def initialize(location:, message:, tree_path: [])
        @location = location
        @message = message
        @tree_path = tree_path
      end

      def to_hash
        {
          type: TYPE,
          location: @location,
          message: @message,
          tree_path: @tree_path
        }
      end
    end
  end
end
