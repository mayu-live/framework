# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "devtools/inspector"

module Mayu
  # Server side of the browser devtools extension in
  # gems/mayu-devtools/extension.
  module Devtools
    def self.install(environment)
      environment.inspector = Inspector.new
    end
  end
end
