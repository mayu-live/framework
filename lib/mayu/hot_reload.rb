# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  # The data a development build hands to running sessions after a source
  # change. Everything here is plain data so the runtime never has to know how
  # the update was produced or how its errors were formatted.
  module HotReload
    ErrorReport =
      Data.define(
        :type,
        :detail,
        :file,
        :line,
        :column,
        :source,
        :hints,
        :backtrace
      ) do
        # "app:/pages/demos/CustomElement.tsx:3:20"
        def location
          return file if line.nil?

          "#{file}:#{[line, column].compact.join(":")}"
        end
      end

    Update =
      Data.define(:errors) do
        def self.success = new(errors: [])
        def self.failure(errors) = new(errors:)

        def success? = errors.empty?
      end
  end
end
