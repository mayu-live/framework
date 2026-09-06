# frozen_string_literal: true

require "klenod/build"
require "klenod/build/watcher"
require "klenod/plugin/css"
require "klenod/plugin/javascript"
require "klenod/rack"
require "klenod/runtime"

require_relative "klenod/configuration"
require_relative "klenod/provider"

module Mayu
  # Mayu's small, explicit boundary to the Klenod platform. Framework code must
  # depend on providers, rather than reaching into a build graph or runtime
  # bundle directly.
  module Klenod
  end
end
