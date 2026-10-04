# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "console/event/generic"

require_relative "error_report"

module Mayu
  module Build
    # What one hot reload did, as a Console event. UpdateLogger emits it,
    # Console::Terminal::Formatter::MayuUpdate draws it on terminals and in
    # text log files, and the JSON output writes #to_hash as it is.
    class UpdateEvent < Console::Event::Generic
      TYPE = :"mayu.update"

      attr_reader :version, :duration, :errors

      def initialize(update:, duration:, source_dir:, provider: nil)
        event = update.event
        result = event.result
        source_dir = Pathname.new(source_dir).expand_path

        @version = event.graph_version
        @duration = duration
        @changed = event.changed_paths.map { relative_path(it, source_dir) }
        @removed = event.removed_paths.map { relative_path(it, source_dir) }
        @reloaded = result&.reloaded_module_ids || []
        @reevaluated = result&.reevaluated_module_ids || []
        @removed_modules = result&.removed_module_ids || []
        @assets = asset_changes(result&.asset_changes)
        @errors =
          update.each_error.map do |module_id, error|
            ErrorReport.from(error, module_id:, provider:)
          end
      end

      def success? = @errors.empty?

      def status = success? ? :completed : :failed

      # True when the update touched no loaded module or asset.
      def empty?
        [@reloaded, @reevaluated, @removed_modules].all?(&:empty?) &&
          @assets.values.all?(&:empty?)
      end

      def to_hash
        {
          type: TYPE,
          version: @version,
          status:,
          duration: @duration,
          changed: @changed,
          removed: @removed,
          reloaded: @reloaded,
          reevaluated: @reevaluated,
          removed_modules: @removed_modules,
          assets: @assets,
          errors: @errors.map(&:to_h)
        }
      end

      private

      def asset_changes(changes)
        return {added: [], changed: [], removed: []} unless changes

        {
          added: changes.added.to_a,
          changed: changes.changed.to_a,
          removed: changes.removed.to_a
        }
      end

      def relative_path(path, source_dir)
        pathname = Pathname.new(path)
        pathname = pathname.expand_path if pathname.absolute?
        pathname.relative_path_from(source_dir).to_s
      rescue ArgumentError
        path.to_s
      end
    end
  end
end
