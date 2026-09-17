# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "console/event/generic"

require_relative "../backtrace"
require_relative "render_error_formatter"

module Mayu
  module Runtime
    # A component raised while rendering or handling an event. Logged through
    # Console, where Console::Terminal::Formatter::MayuRenderError draws it
    # for terminals and text log files and the JSON output writes #to_hash.
    class RenderErrorEvent < Console::Event::Generic
      TYPE = :"mayu.render_error"

      # Call after the provider has rewritten the backtrace to source paths,
      # so app frames can be told apart from Mayu's and matched to sources.
      def self.for(error, component:, provider: nil, root: Dir.pwd)
        backtrace, hidden_frames = Backtrace.split(error.backtrace)
        sources =
          if provider.respond_to?(:source_excerpts)
            provider.source_excerpts(error)
          else
            []
          end

        new(
          component: component&.class&.to_s,
          error: error.class.name,
          message: error.message.to_s,
          backtrace:,
          hidden_frames:,
          sources:,
          root:
        )
      end

      def initialize(component:, error:, message:, backtrace:, hidden_frames:, sources:, root:)
        @component = component
        @error = error
        @message = message
        @backtrace = backtrace
        @hidden_frames = hidden_frames
        @sources = sources
        @root = root
      end

      def to_hash
        {
          type: TYPE,
          component: @component,
          error: @error,
          message: @message,
          backtrace: @backtrace,
          hidden_frames: @hidden_frames,
          sources: @sources,
          root: @root
        }
      end
    end
  end
end
