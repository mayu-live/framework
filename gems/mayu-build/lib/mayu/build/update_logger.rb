# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "console"

require_relative "update_event"
require_relative "console_formatter"

module Mayu
  module Build
    # Reports each hot reload through Console, so it lands wherever the
    # server's other logs go: the terminal, a log file, or JSON.
    class UpdateLogger
      def initialize(source_dir:, provider: nil, logger: nil)
        @source_dir = source_dir
        @provider = provider
        @logger = logger
      end

      # This is the only place a reload failure is reported. Sessions used to
      # log the exception as well, which repeated the whole backtrace once per
      # open browser tab.
      def log(update:, duration:)
        event =
          UpdateEvent.new(
            update:,
            duration:,
            source_dir: @source_dir,
            provider: @provider
          )

        if event.success?
          logger.info(self, event:)
        else
          logger.error(self, event:)
        end
      end

      private

      # Resolved per call: Console's logger is fiber-local and may be replaced
      # after this object is created.
      def logger = @logger || Console.logger
    end
  end
end
