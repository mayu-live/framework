# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "../backtrace"
require_relative "../runtime/h"

module Mayu
  class Session
    module ErrorPage
      H = Runtime::H

      def self.build(message)
        [
          H[:head, H[:title, "Error: #{message}"]],
          H[:body, H[:p, "Error: #{message}"]]
        ]
      end

      # The page shown when a component failed its first render and the app
      # has no +error.haml. With details, as in development, it names the
      # error and the frames through the app; the overlay adds the excerpt
      # once the stream connects.
      def self.render_failure(error, details:)
        return build("Something went wrong") unless details

        frames, hidden = Backtrace.split(error.backtrace)
        frames << "#{hidden} more frames through Mayu" if hidden > 0

        [
          H[:head, H[:title, "Error: #{error.message}"]],
          H[
            :body,
            H[:h1, "#{error.class}: #{error.message}"],
            H[:pre, frames.join("\n")],
            H[:p, "The page renders again once the component is fixed and hot reloaded."]
          ]
        ]
      end
    end
  end
end
