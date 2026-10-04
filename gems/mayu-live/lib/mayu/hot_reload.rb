# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
