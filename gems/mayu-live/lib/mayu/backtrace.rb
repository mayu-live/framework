# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

module Mayu
  # Tells the frames an app developer wrote apart from the ones that run
  # through Mayu, its gems and Ruby itself, so error reports can list the
  # former and only count the latter.
  module Backtrace
    FRAMEWORK_FRAME = %r{/gems/|/vendor/bundle/|<internal:}

    def self.framework_frame?(frame)
      FRAMEWORK_FRAME.match?(frame.to_s)
    end

    # Returns the app frames and how many framework frames were left out.
    def self.split(frames)
      frames = Array(frames).map(&:to_s)
      app_frames = frames.reject { framework_frame?(it) }

      [app_frames, frames.length - app_frames.length]
    end
  end
end
