# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async"
require "async/queue"
require "klenod/build/watcher"

require_relative "../hot_reload"
require_relative "error_report"
require_relative "update_logger"

module Mayu
  module Klenod
    # Watches the app's sources, applies each change to the development
    # provider, and hands the outcome to the App as a HotReload::Update so it
    # can notify its sessions.
    class HotReloader
      def initialize(provider:, source_dir:, root_entry: "root.haml", logger: nil)
        @provider = provider
        @source_dir = source_dir
        @root_entry = root_entry
        @logger = logger || UpdateLogger.new(source_dir:, provider:)
      end

      # Starts watching and returns the task doing it. Stopping the task stops
      # the file watcher.
      def start(app)
        context = @provider.context
        root_entry = @provider.entry(@root_entry)
        events = Async::Queue.new
        context.on_update { |event| events.enqueue(event) }

        watcher = ::Klenod::Build::Watcher.new(source_dir: @source_dir, context:)

        Async do
          watcher.start

          loop do
            event = events.dequeue
            app.notify_hmr_update(to_update(apply(event, root_entry)))
          end
        ensure
          events.close
          watcher.stop
        end
      end

      # Anything escaping here would break out of the watcher loop and stop hot
      # reloading for the rest of the process, so report the failure as an
      # update instead and let sessions render it.
      def apply(event, root_entry)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        update = @provider.apply_update(event, entry: root_entry)
        @logger.log(update:, duration: format_duration(start_time))
        update
      rescue StandardError, ScriptError => e
        Console.logger.error(self, e)
        ::Klenod::Build::AppliedUpdate.new(event, nil, nil, nil, [[nil, e]].freeze)
      end

      def to_update(applied)
        return HotReload::Update.success if applied.success?

        errors = []
        applied.each_error do |module_id, error|
          rewrite_backtrace(error)
          errors << ErrorReport.from(error, module_id:, provider: @provider)
        end
        HotReload::Update.failure(errors)
      end

      private

      def rewrite_backtrace(error)
        return unless error.is_a?(Exception)

        @provider.rewrite_exception(error)
      rescue => rewrite_error
        Console.logger.warn(
          self,
          "Could not rewrite reload error backtrace: #{rewrite_error.message}"
        )
      end

      def format_duration(start_time)
        "%.4fms" % ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1_000)
      end
    end
  end
end
