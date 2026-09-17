# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "commands"
require_relative "render_error_event"

module Mayu
  module Runtime
    # What happens when a component raises while rendering or handling an
    # event, wherever that is caught: one Console entry through
    # RenderErrorEvent, and the command that shows the overlay in the browser.
    module RenderError
      def self.report(error, component:, tree_path: [], provider: nil)
        provider.rewrite_exception(error) if provider.respond_to?(:rewrite_exception)

        Console.logger.error(
          component,
          event: RenderErrorEvent.for(error, component:, provider:)
        )

        Commands::RenderError[
          label_for(component),
          error.class.name,
          error.message,
          error.backtrace,
          nil,
          tree_path,
          nil,
          nil,
          []
        ]
      end

      def self.label_for(component)
        klass = component.class
        path = klass.module_path if klass.respond_to?(:module_path)
        (path.nil? || path.empty?) ? klass.name : path
      end
    end
  end
end
