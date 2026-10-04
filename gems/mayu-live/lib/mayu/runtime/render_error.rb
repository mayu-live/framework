# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "../backtrace"
require_relative "commands"
require_relative "render_error_event"

module Mayu
  module Runtime
    # What happens when a component raises while rendering or handling an
    # event, wherever that is caught: one Console entry through
    # RenderErrorEvent, and the command that shows the overlay in the browser.
    module RenderError
      # "file:12", "file:12:34" or "file:12:in 'method'". Module ids contain
      # colons, so the line is the first number after the file.
      FRAME = /\A(?<file>.*?):(?<line>\d+)(?<rest>(?::\d+)?(?::in .*)?)\z/m

      # The overlay command names modules the way the log does. With
      # `with_source`, as in development, it also carries the source of the
      # module the exception was raised in and the line, so the overlay can
      # show the excerpt. Production never shows the overlay, so it skips
      # that lookup.
      def self.report(error, component:, tree_path: [], provider: nil, with_source: false)
        provider.rewrite_exception(error) if provider.respond_to?(:rewrite_exception)

        event = RenderErrorEvent.for(error, component:, provider:, tree_path:)
        Console.logger.error(event.component || component, event:)

        location =
          if with_source && provider.respond_to?(:source_location)
            provider.source_location(error)
          end

        Commands::RenderError[
          location&.dig(:file) || event.component || label_for(component),
          error.class.name,
          error.message,
          Array(error.backtrace).map { |frame| short_frame(frame, provider) },
          location&.dig(:source),
          event.to_hash[:tree_path].map { |node| node.slice(:name, :path) },
          location&.dig(:line),
          nil,
          []
        ]
      end

      # Frames name app files by module id and gem files relative to their
      # gem, so the overlay can tell the two apart and neither shows where
      # the app is checked out.
      def self.short_frame(frame, provider)
        match = FRAME.match(frame.to_s)
        return frame.to_s unless match

        file = match[:file]
        id = module_id_for(file, provider) unless Backtrace.framework_frame?(file)
        return "#{id}:#{match[:line]}#{match[:rest]}" if id

        _, separator, gem_path = file.rpartition("/gems/")
        file = gem_path unless separator.empty?

        "#{file}:#{match[:line]}#{match[:rest]}"
      end

      # The provider raises its own error for a file that is not a module.
      def self.module_id_for(file, provider)
        return nil unless provider.respond_to?(:module_id_for)

        provider.module_id_for(file).to_s
      rescue
        nil
      end

      def self.label_for(component)
        klass = component.class
        path = klass.module_path if klass.respond_to?(:module_path)
        (path.nil? || path.empty?) ? klass.name : path
      end
    end
  end
end
