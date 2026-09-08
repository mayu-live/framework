# frozen_string_literal: true

require "klenod/build"
require "klenod/build/watcher"
require "klenod/plugin/css"
require "klenod/plugin/javascript"
require "klenod/rack"
require "klenod/runtime"
require "klenod/test"

require_relative "route"
require_relative "klenod/configuration"
require_relative "klenod/provider"
require_relative "klenod/component_resolver"
require_relative "klenod/router"
require_relative "klenod/asset_app"
require_relative "klenod/update_logger"

module Mayu
  module ModuleNamespace
  end

  # Mayu's small, explicit boundary to the Klenod platform. Framework code must
  # depend on providers, rather than reaching into a build graph or runtime
  # bundle directly.
  module Klenod
  end
end
