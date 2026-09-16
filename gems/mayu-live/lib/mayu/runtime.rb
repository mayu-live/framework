# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

module Mayu
  module Runtime
    autoload :Engine, File.join(__dir__, "runtime", "engine")

    def self.init(descriptor, metrics:, runtime_js:, render_exceptions: true)
      Engine.new(descriptor, metrics:, runtime_js:, render_exceptions:)
    end
  end
end
