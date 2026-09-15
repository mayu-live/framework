# frozen_string_literal: true

require "klenod/build"
require "klenod/build/watcher"
require "klenod/plugin/css"
require "klenod/plugin/javascript"
require "klenod/test"

require_relative "klenod"
require_relative "build/development_provider"
require_relative "build/configuration"
require_relative "build/error_report"
require_relative "build/update_logger"
require_relative "build/hot_reloader"

module Mayu
  module ModuleNamespace
  end

  # Everything that needs klenod-build: compiling and watching app sources,
  # producing bundles, and the tooling around them. Nothing under `Mayu::Build`
  # may be required by the production server.
  module Build
  end
end
